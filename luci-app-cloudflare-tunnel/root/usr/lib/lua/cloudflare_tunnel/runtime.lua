-- SPDX-License-Identifier: GPL-3.0-only
local core = require "cloudflare_tunnel.core"
local json = require "luci.jsonc"
local nixio = require "nixio"
local fs = require "nixio.fs"
local uci = require "uci"
local ubus = require "ubus"
local M = {}
local CONFIG = "cloudflare-tunnel"
local DIR = "/etc/cloudflare-tunnel"
local RUN = "/var/run/cloudflare-tunnel"
local LOCK = RUN .. "/lock"
local STATE = DIR .. "/state.json"
local JOB = RUN .. "/status.json"

local function read_json(path)
	local ok, result = pcall(json.parse, fs.readfile(path) or "")
	return ok and type(result) == "table" and result or {}
end

local function write(path, data)
	local f = nixio.open(path .. ".new", "w", 600)
	if not f then core.fail("storage", "Cannot write the router configuration.") end
	local ok = f:writeall(data)
	f:close()
	if not ok or not fs.rename(path .. ".new", path) then core.fail("storage", "Cannot save the router configuration.") end
	fs.chmod(path, 600)
end

local function write_json(path, data)
	write(path, json.stringify(data))
end

local function prepare()
	nixio.umask(77)
	for _, path in ipairs({ DIR, RUN }) do
		if not fs.stat(path) and not fs.mkdir(path, 700) then core.fail("storage", "Cannot create the plugin state directory.") end
		fs.chmod(path, 700)
	end
end

local function config()
	local c = uci.cursor()
	local values = c:get_all(CONFIG, "main") or {}
	c:close()
	return values
end

local function update_config(values)
	local c = uci.cursor()
	if not c:get(CONFIG, "main") then c:section(CONFIG, "tunnel", "main", {}) end
	for key, value in pairs(values) do c:set(CONFIG, "main", key, value) end
	local ok = c:commit(CONFIG)
	c:close()
	fs.chmod("/etc/config/" .. CONFIG, 600)
	if not ok then core.fail("storage", "Cannot commit the router configuration.") end
end

-- No shell is involved. API credentials travel through an unlinked 0600
-- stdin file, never argv, a world-readable file, or the RPC response.
local function execute(argv, input, timeout)
	local output = nixio.mkstemp("cloudflare-response")
	local stdin = nixio.mkstemp("cloudflare-request")
	if not output or not stdin then
		if output then output:close() end
		if stdin then stdin:close() end
		core.fail("storage", "Cannot allocate a temporary request file.")
	end
	stdin:writeall(input or "")
	stdin:seek(0, "set")
	local pid = nixio.fork()
	if not pid then stdin:close(); output:close(); core.fail("process", "Cannot start a helper process.") end
	if pid == 0 then
		local null = nixio.open("/dev/null", "r+")
		if not null or not nixio.dup(stdin, nixio.stdin) or not nixio.dup(output, nixio.stdout) or not nixio.dup(null, nixio.stderr) then os.exit(127) end
		stdin:close(); output:close(); null:close()
		nixio.exec(unpack(argv))
		os.exit(127)
	end
	stdin:close()
	local code
	for _ = 1, (timeout or 40) * 10 do
		local done, kind, status = nixio.waitpid(pid, "nohang")
		if done then code = kind == "exited" and status or 128; break end
		nixio.poll({}, 100)
	end
	if not code then nixio.kill(pid, 9); nixio.waitpid(pid); code = 124 end
	output:seek(0, "set")
	local chunks, size = {}, 0
	while size <= 2097152 do
		local chunk = output:read(8192)
		if not chunk or chunk == "" then break end
		chunks[#chunks + 1] = chunk
		size = size + #chunk
	end
	output:close()
	if size > 2097152 then return "", 125 end
	return table.concat(chunks), code
end

local function curl_quote(value)
	return '"' .. tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\r", "\\r"):gsub("\n", "\\n") .. '"'
end

local function request(url, options)
	options = options or {}
	local lines = { "silent", "show-error", "connect-timeout = 10", "max-time = " .. (options.timeout or 35),
		"max-filesize = 2097152", "url = " .. curl_quote(url), 'write-out = "\\n%{http_code}"' }
	if options.method then lines[#lines + 1] = "request = " .. curl_quote(options.method) end
	if options.token then lines[#lines + 1] = "header = " .. curl_quote("Authorization: Bearer " .. options.token) end
	if options.body then
		lines[#lines + 1] = 'header = "Content-Type: application/json"'
		lines[#lines + 1] = "data = " .. curl_quote(json.stringify(options.body))
	end
	for _, header in ipairs(options.headers or {}) do lines[#lines + 1] = "header = " .. curl_quote(header) end
	if options.resolve then lines[#lines + 1] = "resolve = " .. curl_quote(options.resolve) end
	if options.insecure then lines[#lines + 1] = "insecure" end
	if options.include then lines[#lines + 1] = "include" end
	local raw, code = execute({ "/usr/bin/curl", "--config", "-" }, table.concat(lines, "\n") .. "\n", (options.timeout or 35) + 5)
	local body, status = raw:match("^(.*)\n(%d%d%d)$")
	return body or "", tonumber(status) or 0, code
end

local permissions = {
	zone = "Zone / Zone / Read, including the hostname's zone",
	dns = "Zone / DNS / Edit, including the hostname's zone",
	tunnel = "Account / Cloudflare Tunnel / Edit, including the zone's account"
}

local function client(token)
	return function(method, path, body, scope)
		local raw, status, code
		for attempt = 1, 3 do
			raw, status, code = request("https://api.cloudflare.com/client/v4" .. path,
				{ method = method, token = token, body = body })
			-- Retrying a POST after a lost response can create duplicate resources.
			if method ~= "GET" or (status ~= 429 and status < 500) or attempt == 3 then break end
			nixio.poll({}, attempt * 1000)
		end
		if code ~= 0 then core.fail("network", "Cannot reach Cloudflare (curl exit " .. code .. "). Check Internet access and the router clock.") end
		if status == 401 or status == 403 then
			core.fail("permission_" .. (scope or "zone"), "Cloudflare rejected this operation. The same API token needs " .. (permissions[scope] or permissions.zone) .. ".")
		end
		if status == 429 then core.fail("rate_limit", "Cloudflare's API rate limit was reached. Retry later.") end
		local ok, data = pcall(json.parse, raw)
		if not ok or type(data) ~= "table" then core.fail("api", "Cloudflare returned an invalid API response.") end
		if status < 200 or status >= 300 or data.success ~= true then
			local messages = {}
			for _, item in ipairs(type(data.errors) == "table" and data.errors or {}) do
				if type(item.message) == "string" then messages[#messages + 1] = item.message end
			end
			local message = table.concat(messages, "; "):sub(1, 1000)
			message = message:gsub(token:gsub("([^%w])", "%%%1"), "[redacted]")
			core.fail("api", "Cloudflare API HTTP " .. status .. (message ~= "" and ": " .. message or ""))
		end
		return data.result, data.result_info
	end
end

local function running()
	local conn = ubus.connect()
	if not conn then return false end
	local reply = conn:call("service", "list", { name = CONFIG })
	conn:close()
	for _, instance in pairs(reply and reply[CONFIG] and reply[CONFIG].instances or {}) do
		if instance.running then return true end
	end
	return false
end

local function connected()
	if not running() then return false end
	local _, status, code = request("http://127.0.0.1:20242/ready", { timeout = 2 })
	return code == 0 and status == 200
end

local function device_id()
	local cfg = config()
	local value = cfg.device_id
	if value and value:match("^%x+$") and #value == 12 then return value end
	value = (fs.readfile("/sys/class/net/br-lan/address") or ""):gsub("[^%x]", ""):lower()
	if #value ~= 12 or value == "000000000000" then value = (fs.readfile("/proc/sys/kernel/random/uuid") or ""):gsub("%-", ""):sub(1, 12) end
	if #value ~= 12 or not value:match("^%x+$") then core.fail("device", "Cannot determine a stable router identifier.") end
	update_config({ device_id = value })
	return value
end

local function origin(settings)
	local passwords, logins = {}, {}
	for user, hash in (fs.readfile("/etc/shadow") or ""):gmatch("([^:\n]+):([^:\n]*):[^\n]*") do passwords[user] = hash end
	local c = uci.cursor()
	c:foreach("rpcd", "login", function(login) logins[#logins + 1] = login end)
	c:close()
	if not core.web_passwords_set(logins, function(user) return passwords[user] end) then
		core.fail("password", "Set a password for the router's web administrator before publishing its management page.")
	end
	local value = config().origin or "http://127.0.0.1:80"
	local scheme, address = value:match("^(https?)://([^/]+)$")
	local host, port = (address or ""):match("^(.-):(%d+)$")
	if not host then host = address end
	if not scheme or (host ~= "127.0.0.1" and host ~= "localhost" and host ~= "[::1]") or (port and (tonumber(port) < 1 or tonumber(port) > 65535)) then
		core.fail("origin", "The origin must be an HTTP or HTTPS service on this router's loopback interface.")
	end
	local body, status, code = request(value .. "/", { timeout = 5, include = true, insecure = scheme == "https", headers = { "Host: " .. settings.hostname } })
	if scheme == "http" and status >= 300 and status < 400 and body:lower():match("\nlocation:%s*https://") then
		local location = body:match("[Ll]ocation:%s*([^\r\n]+)") or ""
		local https_port = location:match("^https://[^/]+:(%d+)") or "443"
		value = "https://127.0.0.1:" .. https_port
		_, status, code = request(value .. "/", { timeout = 5, insecure = true, headers = { "Host: " .. settings.hostname } })
	end
	if code ~= 0 or status < 200 or status >= 500 then core.fail("origin", "The router's local web management service is not reachable.") end
	return value
end

local function verify(hostname)
	local ready = false
	for _ = 1, 8 do
		ready = connected()
		if ready then break end
		nixio.poll({}, 2000)
	end
	local function probe(resolve)
		local response, status, code = request("https://" .. hostname .. "/", { timeout = 10, include = true, resolve = resolve })
		local headers = (response:match("^(.-)\r?\n\r?\n") or ""):lower()
		-- A cached wildcard may still reach another HTTPS origin with a valid
		-- certificate. Require evidence that this response crossed Cloudflare.
		return code == 0 and status >= 200 and status < 500 and status ~= 404 and headers:find("\ncf%-ray:") ~= nil
	end
	local https_ok = probe()
	local dns_cache_pending = false
	if not https_ok then
		-- A pre-existing wildcard can leave a recursive resolver with an old
		-- answer. Verify the public route independently without disabling TLS.
		local raw, dns_status, dns_code = request("https://cloudflare-dns.com/dns-query?name=" .. hostname .. "&type=A",
			{ timeout = 10, headers = { "Accept: application/dns-json" } })
		local ok, data = pcall(json.parse, raw)
		if dns_code == 0 and dns_status == 200 and ok and type(data) == "table" then
			for _, answer in ipairs(data.Answer or {}) do
				if answer.type == 1 and type(answer.data) == "string" and answer.data:match("^%d+%.%d+%.%d+%.%d+$") then
					https_ok = probe(hostname .. ":443:" .. answer.data)
					dns_cache_pending = https_ok
					break
				end
			end
		end
	end
	return { connected = ready, https_ok = https_ok, dns_cache_pending = dns_cache_pending }
end

local function active_job(job)
	local pid = tonumber(job.pid)
	if not pid or pid <= 1 or not nixio.kill(pid, 0) then return false end
	local command = fs.readfile("/proc/" .. pid .. "/cmdline") or ""
	return command:find("cloudflare_tunnel", 1, true) ~= nil or command:find("cloudflare-tunnel", 1, true) ~= nil
end

local function lock()
	prepare()
	if fs.mkdir(LOCK, 700) then return end
	local job = read_json(JOB)
	local stat = fs.stat(LOCK)
	-- The directory can exist before its creator has written the job file.
	if (stat and os.time() - stat.mtime < 10) or (job.phase == "deploying" and active_job(job)) then
		core.fail("busy", "A deployment is already in progress.")
	end
	fs.rmdir(LOCK)
	if not fs.mkdir(LOCK, 700) then core.fail("busy", "A deployment is already in progress.") end
end

local function job_status(values)
	values.updated_at = os.time()
	write_json(JOB, values)
end

local function activate(token)
	local previous = fs.readfile(DIR .. "/tunnel.token")
	write(DIR .. "/tunnel.token", token .. "\n")
	update_config({ enabled = "1" })
	local _, enable_code = execute({ "/etc/init.d/" .. CONFIG, "enable" }, "", 10)
	local _, restart_code = execute({ "/etc/init.d/" .. CONFIG, "restart" }, "", 15)
	if enable_code ~= 0 or restart_code ~= 0 then
		if previous then write(DIR .. "/tunnel.token", previous) else fs.unlink(DIR .. "/tunnel.token") end
		core.fail("service", "Cannot start the Cloudflare Tunnel service.")
	end
end

local function worker(settings)
	local ok, result = pcall(function()
		return core.deploy({
			api = client(settings.api_token), device_id = device_id(), origin = function() return origin(settings) end,
			activate = activate, verify = verify, time = os.time,
			save = function(state) write_json(STATE, state) end,
			progress = function(stage) job_status({ phase = "deploying", stage = stage, pid = nixio.getpid(), hostname = settings.hostname }) end
		}, settings, read_json(STATE))
	end)
	if ok then
		result.phase = result.connected and "ready" or "connecting"
		result.stage = "complete"
		job_status(result)
	else
		local err = type(result) == "table" and result or { code = "internal", message = "Deployment failed unexpectedly. Retry the deployment." }
		job_status({ phase = "error", hostname = settings.hostname, error = err })
	end
	fs.rmdir(LOCK)
	if not ok then error(result, 0) end
	return result
end

function M.settings()
	local cfg = config()
	return { hostname = cfg.hostname or "", api_token = "", token_saved = type(cfg.api_token) == "string" and #cfg.api_token > 0 }
end

-- Read-only preflight for diagnostics and integration tests. No API resource or
-- router configuration is created, including for account-owned API tokens.
function M.check(input)
	local settings = core.settings(input or config(), config())
	local api = client(settings.api_token)
	local zone = core.find_zone(api, settings.hostname)
	local records = api("GET", "/zones/" .. zone.id .. "/dns_records?name=" .. settings.hostname .. "&per_page=100", nil, "dns")
	api("GET", "/accounts/" .. zone.account.id .. "/cfd_tunnel?is_deleted=false&per_page=1", nil, "tunnel")
	return { checked = true, hostname = settings.hostname, zone = zone.name, account_id = zone.account.id,
		origin = origin(settings), existing_dns_records = #records }
end

function M.status()
	local job = read_json(JOB)
	local state = read_json(STATE)
	local cfg = config()
	job.token_saved = type(cfg.api_token) == "string" and #cfg.api_token > 0
	local live = connected()
	local is_running = running()
	if job.phase == "deploying" then
		if active_job(job) or os.time() - (tonumber(job.updated_at) or 0) < 10 then
			job.connected = live
			job.running = is_running
			job.hostname = state.active and state.active.hostname
			return job
		end
		job = { phase = "error", token_saved = job.token_saved, error = { code = "interrupted", message = "The previous deployment was interrupted. Retry to resume it." } }
	end
	if job.phase ~= "error" then job.phase = live and "ready" or (is_running and "connecting" or (state.active and "stopped" or "unconfigured")) end
	job.running = is_running
	job.connected = live
	job.hostname = state.active and state.active.hostname or job.hostname
	job.https_ok = state.https_ok == true
	job.dns_cache_pending = state.dns_cache_pending == true
	job.checked_at = state.checked_at
	job.tunnel_id = state.active and state.active.tunnel_id
	return job
end

function M.deploy(input, foreground)
	lock()
	local ok, result = pcall(function()
		local settings = core.settings(input, config())
		update_config(settings)
		job_status({ phase = "deploying", stage = "zone", pid = nixio.getpid(), hostname = settings.hostname })
		if foreground then return worker(settings) end
		local pid = nixio.fork()
		if not pid then core.fail("process", "Cannot start the deployment worker.") end
		if pid == 0 then
			nixio.setsid()
			local child = nixio.fork()
			if not child then os.exit(1) end
			if child > 0 then os.exit(0) end
			local null = nixio.open("/dev/null", "r+")
			if not null then os.exit(1) end
			nixio.dup(null, nixio.stdin); nixio.dup(null, nixio.stdout); nixio.dup(null, nixio.stderr); null:close()
			-- A fresh interpreter has no inherited RPC frames or buffered JSON.
			-- Only the queued configuration is read, never a token in argv.
			nixio.exec("/usr/libexec/cloudflare-tunnel", "worker")
			os.exit(127)
		end
		nixio.waitpid(pid)
		return { accepted = true }
	end)
	if not ok then fs.rmdir(LOCK); error(result, 0) end
	return result
end

function M.stop()
	lock()
	local ok, err = pcall(function()
		update_config({ enabled = "0" })
		local _, stop_code = execute({ "/etc/init.d/" .. CONFIG, "stop" }, "", 15)
		local _, disable_code = execute({ "/etc/init.d/" .. CONFIG, "disable" }, "", 10)
		if stop_code ~= 0 or disable_code ~= 0 then core.fail("service", "Cannot stop or disable the tunnel service.") end
		job_status({ phase = "stopped" })
	end)
	fs.rmdir(LOCK)
	if not ok then error(err, 0) end
	return { stopped = true }
end

function M.foreground()
	return M.deploy(config(), true)
end

function M.queued()
	if not fs.stat(LOCK) or read_json(JOB).phase ~= "deploying" then core.fail("busy", "No queued deployment is available.") end
	local cfg = config()
	return worker(core.settings(cfg, cfg))
end

function M.safe(fn)
	local ok, result = pcall(fn)
	if ok then return result end
	return { error = type(result) == "table" and result or { code = "internal", message = "The operation could not be completed." } }
end

return M

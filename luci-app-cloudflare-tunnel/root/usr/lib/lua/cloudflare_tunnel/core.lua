-- SPDX-License-Identifier: GPL-3.0-only
-- Deployment policy is independent of router IO so failure recovery can be tested.
local M = {}

local function fail(code, message)
	error({ code = code, message = message }, 0)
end
M.fail = fail

function M.web_passwords_set(logins, shadow_password)
	local usable = false
	for _, login in ipairs(logins) do
		if type(login.password) == "string" then
			local hash = login.password
			local reference = hash:match("^%$p%$(.+)$")
			if reference then hash = shadow_password(reference) end
			-- rpcd accepts an empty configured password or shadow hash.
			if hash == "" then return false end
			if hash and hash:sub(1, 1) ~= "!" and hash:sub(1, 1) ~= "*" then usable = true end
		end
	end
	return usable
end

local function trim(value)
	return type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
end

function M.hostname(value)
	value = trim(value):lower():gsub("%.$", "")
	if #value < 3 or #value > 253 or not value:find("%.") or value:find("%.%.") then
		fail("hostname", "Enter a complete hostname, such as abc.example.com.")
	end
	local count = 0
	for label in value:gmatch("[^.]+") do
		count = count + 1
		if #label > 63 or not label:match("^[a-z0-9][a-z0-9%-]*$") or label:sub(-1) == "-" then
			fail("hostname", "Use DNS labels containing letters, digits and hyphens; use Punycode for international names.")
		end
	end
	if count > 20 or value:sub(1, 1) == "." then fail("hostname", "Invalid hostname.") end
	return value
end

function M.settings(input, previous)
	if type(input) ~= "table" then fail("settings", "Missing configuration.") end
	local token = trim(input.api_token)
	if token == "" then token = previous and previous.api_token or "" end
	if #token < 20 or #token > 512 or not token:match("^[A-Za-z0-9_%-]+$") then
		fail("token", "Enter a Cloudflare API token.")
	end
	return { hostname = M.hostname(input.hostname), api_token = token }
end

local function id(value)
	return type(value) == "string" and #value == 32 and value:match("^%x+$")
end

local function uuid(value)
	return type(value) == "string" and value:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$")
end

function M.find_zone(api, hostname)
	local candidate = hostname
	while candidate:find("%.") do
		local zones = api("GET", "/zones?name=" .. candidate .. "&per_page=50", nil, "zone")
		for _, zone in ipairs(zones or {}) do
			if zone.name == candidate and zone.status == "active" then
				if not id(zone.id) or type(zone.account) ~= "table" or not id(zone.account.id) then
					fail("api", "Cloudflare returned an invalid zone or account ID.")
				end
				if hostname == zone.name then fail("hostname", "Enter a subdomain, not the zone's root domain.") end
				local prefix = hostname:sub(1, #hostname - #zone.name - 1)
				if prefix:find("%.") then
					fail("certificate", "Use a first-level subdomain for a free certificate, such as abc.example.com.")
				end
				return zone
			end
		end
		candidate = candidate:match("^[^.]+%.(.+)$") or ""
	end
	fail("zone", "No active Cloudflare zone matches this hostname. Check Zone Read permission and the token's zone scope.")
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = copy(item) end
	return out
end

local function ingress_for(config, hostname, origin, active)
	local rules, catchall = {}, nil
	for _, rule in ipairs(config.ingress or {}) do
		if not rule.hostname then
			catchall = copy(rule)
		elseif rule.hostname == hostname then
			if rule.service ~= origin then fail("conflict", "This tunnel hostname already points to a different service.") end
		elseif active and rule.hostname == active.hostname then
			if rule.service ~= active.origin then fail("conflict", "The previously managed tunnel route was changed outside this plugin.") end
		else
			rules[#rules + 1] = copy(rule)
		end
	end
	local route = { hostname = hostname, service = origin }
	-- This exception is restricted to HTTPS over loopback, never an Internet origin.
	if origin:match("^https://") then route.originRequest = { noTLSVerify = true } end
	rules[#rules + 1] = route
	rules[#rules + 1] = catchall or { service = "http_status:404" }
	local out = copy(config)
	out.ingress = rules
	return out
end

local function matching_dns(records, hostname, target)
	if #records == 0 then return nil end
	local record = records[1]
	if #records ~= 1 or record.name ~= hostname or record.type ~= "CNAME" or record.content ~= target then
		fail("conflict", "The hostname already has a DNS record pointing elsewhere. It was not changed.")
	end
	return record
end

function M.deploy(ctx, settings, state)
	state.tunnels = state.tunnels or {}
	state.dns = state.dns or {}
	local api, hostname = ctx.api, settings.hostname
	local origin = ctx.origin()
	ctx.progress("zone")
	local zone = M.find_zone(api, hostname)
	local aid, zid = zone.account.id, zone.id
	local tunnel_path = "/accounts/" .. aid .. "/cfd_tunnel"
	local dns_path = "/zones/" .. zid .. "/dns_records"
	-- Check both resource scopes, and DNS conflicts, before creating anything.
	local records = api("GET", dns_path .. "?name=" .. hostname .. "&per_page=100", nil, "dns") or {}
	local name = "xwrt-" .. ctx.device_id
	local tunnels = api("GET", tunnel_path .. "?name=" .. name .. "&is_deleted=false&per_page=100", nil, "tunnel") or {}
	local tunnel
	for _, item in ipairs(tunnels) do
		if item.name == name then
			if tunnel then fail("conflict", "More than one tunnel has this router's tunnel name.") end
			tunnel = item
		end
	end
	local saved = state.tunnels[aid]
	if tunnel then
		if not saved or (saved.id ~= tunnel.id and not (saved.pending and saved.name == name)) then
			fail("conflict", "A tunnel with this router's name already exists but is not managed by this plugin.")
		end
		if tunnel.remote_config == false or tunnel.config_src == "local" then fail("conflict", "This tunnel is locally managed.") end
		if saved.pending then
			state.tunnels[aid] = { id = tunnel.id, name = name }
			ctx.save(state)
		end
	elseif saved then
		-- A missing tunnel is recoverable only when no published DNS still depends on it.
		if #records > 0 then fail("conflict", "The saved tunnel is missing, but the hostname still has a DNS record.") end
	end
	local target = tunnel and tunnel.id .. ".cfargotunnel.com" or ""
	local record = matching_dns(records, hostname, target)
	ctx.progress("tunnel")
	local connector_token
	if not tunnel then
		-- Record intent before POST, including when the server creates a tunnel
		-- but its response is lost. The next run reconciles the unique name.
		state.tunnels[aid] = { name = name, pending = true }
		ctx.save(state)
		tunnel = api("POST", tunnel_path, { name = name, config_src = "cloudflare" }, "tunnel")
		if type(tunnel) ~= "table" or not uuid(tunnel.id) then fail("api", "Cloudflare returned an invalid tunnel ID.") end
		state.tunnels[aid] = { id = tunnel.id, name = name }
		ctx.save(state) -- A later failure must not create a second tunnel on retry.
		connector_token = tunnel.token
	end
	if not uuid(tunnel.id) then fail("api", "Cloudflare returned an invalid tunnel ID.") end
	target = tunnel.id .. ".cfargotunnel.com"
	local route_path = tunnel_path .. "/" .. tunnel.id .. "/configurations"
	local current = api("GET", route_path, nil, "tunnel") or {}
	local active = state.active and state.active.tunnel_id == tunnel.id and state.active or nil
	local config = ingress_for(current.config or {}, hostname, origin, active)
	connector_token = connector_token or api("GET", tunnel_path .. "/" .. tunnel.id .. "/token", nil, "tunnel")
	if type(connector_token) ~= "string" or #connector_token > 4096 or not connector_token:match("^[A-Za-z0-9_+/=%-]+$") then
		fail("api", "Cloudflare returned an invalid connector token.")
	end
	ctx.progress("dns")
	local key = zid .. "/" .. hostname
	if record and state.dns[key] and state.dns[key].pending and state.dns[key].tunnel_id == tunnel.id then
		state.dns[key].id = record.id
		state.dns[key].pending = nil
		ctx.save(state)
	end
	if not record then
		state.dns[key] = { zone_id = zid, hostname = hostname, tunnel_id = tunnel.id, owned = true, pending = true }
		ctx.save(state)
		record = api("POST", dns_path, { type = "CNAME", name = hostname, content = target, proxied = true, ttl = 1,
			comment = "Managed by X-WRT Cloudflare Tunnel (" .. ctx.device_id .. ")" }, "dns")
		if type(record) ~= "table" or not id(record.id) then fail("api", "Cloudflare returned an invalid DNS record ID.") end
		state.dns[key] = { id = record.id, zone_id = zid, hostname = hostname, tunnel_id = tunnel.id, owned = true }
		ctx.save(state)
	elseif not record.proxied then
		if not state.dns[key] or state.dns[key].id ~= record.id or not state.dns[key].owned then
			fail("conflict", "The existing DNS record is not proxied and is not managed by this plugin.")
		end
		api("PATCH", dns_path .. "/" .. record.id, { proxied = true }, "dns")
	end
	ctx.progress("configure")
	api("PUT", route_path, { config = config }, "tunnel")
	ctx.progress("start")
	ctx.activate(connector_token)
	state.active = { account_id = aid, zone_id = zid, tunnel_id = tunnel.id, hostname = hostname, dns_id = record.id, origin = origin }
	ctx.save(state)
	local warnings = {}
	for old_key, old in pairs(state.dns) do
		if old_key ~= key and old.owned then
			local ok = pcall(function()
				if not old.id then
					local matches = api("GET", "/zones/" .. old.zone_id .. "/dns_records?name=" .. old.hostname .. "&per_page=100", nil, "dns") or {}
					if #matches == 0 then return end
					if #matches ~= 1 then return end
					old.id = matches[1].id
				end
				local path = "/zones/" .. old.zone_id .. "/dns_records/" .. old.id
				local existing = api("GET", path, nil, "dns")
				if existing and existing.name == old.hostname and existing.type == "CNAME" and existing.content == old.tunnel_id .. ".cfargotunnel.com" then
					api("DELETE", path, nil, "dns")
				end
			end)
			if ok then state.dns[old_key] = nil else warnings[#warnings + 1] = "An old DNS record could not be removed; check its zone permissions." end
		end
	end
	ctx.progress("https")
	local check = ctx.verify(hostname, aid, tunnel.id) or {}
	state.https_ok = check.https_ok == true
	state.dns_cache_pending = check.dns_cache_pending == true
	state.checked_at = ctx.time()
	ctx.save(state)
	return { hostname = hostname, tunnel_id = tunnel.id, https_ok = state.https_ok,
		connected = check.connected == true, dns_cache_pending = state.dns_cache_pending, warnings = warnings }
end

return M

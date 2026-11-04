-- Run with Lua 5.1. Router IO and curl responses are simulated.
local test_dir = arg[0]:match("^(.*)/[^/]+$") or "."
package.path = test_dir .. "/../root/usr/lib/lua/?.lua;" .. package.path
local core = require "cloudflare_tunnel.core"
local TOKEN = "test-token_with-hyphens-1234567890"

local function fixture(responses)
	local state = { calls = {}, open_files = 0 }
	local files = {}
	local nixio = {
		mkstemp = function(name)
			local file = assert(io.tmpfile())
			local handle = {
				writeall = function(_, data) return file:write(data) end,
				seek = function(_, offset, whence) return file:seek(whence, offset) end,
				-- nixio can return less than requested even for regular files.
				read = function(_, size) return file:read(math.min(size, 1024)) end,
				close = function() state.open_files = state.open_files - 1; file:close() end
			}
			state.open_files = state.open_files + 1
			files[name] = handle
			return handle
		end,
		fork = function()
			local response = assert(table.remove(responses, 1), "unexpected curl call")
			local input = files["cloudflare-request"]:read(2097152)
			state.calls[#state.calls + 1] = input
			files["cloudflare-response"]:writeall((response.body or "") .. "\n" .. (response.status or "000"))
			files["cloudflare-error"]:writeall(response.detail or "")
			state.code = response.code or 0
			return 123
		end,
		waitpid = function(pid) return pid, "exited", state.code end,
		poll = function() end
	}
	local config = { hostname = "router.example.com", api_token = TOKEN }
	local modules = {
		["cloudflare_tunnel.core"] = core,
		["nixio"] = nixio,
		["nixio.fs"] = { readfile = function() return "" end },
		["ubus"] = {},
		["uci"] = { cursor = function() return {
			get_all = function() return config end,
			foreach = function(_, _, _, callback) callback({ username = "admin", password = "$6$hash" }) end,
			close = function() end
		} end },
		["luci.jsonc"] = { parse = function(raw)
			local results = {
				empty = {},
				zone = { { name = "example.com", status = "active", id = string.rep("1", 32), account = { id = string.rep("2", 32) } } }
			}
			return results[raw] and { success = true, result = results[raw] } or nil
		end }
	}
	local chunk = assert(loadfile(test_dir .. "/../root/usr/lib/lua/cloudflare_tunnel/runtime.lua"))
	setfenv(chunk, setmetatable({ require = function(name) return assert(modules[name], name) end }, { __index = _G }))
	local runtime = chunk()
	function state.check()
		local result = runtime.safe(runtime.check)
		assert(state.open_files == 0, "temporary files leaked")
		return result
	end
	return state
end

local tests = {}
function tests.mbedtls_curve_failure_is_actionable_and_token_is_redacted()
	local f = fixture({ { code = 35, detail = "curl: (35) ssl_handshake returned: (-0x3A00) PK - Elliptic curve is unsupported\nAuthorization: Bearer " .. TOKEN .. "\n" } })
	local result = f.check()
	assert(result.error.code == "network")
	assert(result.error.message:find("CONFIG_MBEDTLS_ECP_DP_SECP384R1_ENABLED=y", 1, true))
	assert(result.error.message:find("-0x3A00", 1, true))
	assert(result.error.message:find("[redacted]", 1, true))
	assert(not result.error.message:find(TOKEN, 1, true))
	assert(not result.error.message:find("\n", 1, true))
	assert(f.calls[1]:find("Authorization: Bearer " .. TOKEN, 1, true))
end

function tests.certificate_failure_mentions_clock_and_ca_bundle()
	local f = fixture({ { code = 60, detail = "curl: (60) certificate verify failed\n" } })
	local result = f.check()
	assert(result.error.code == "network")
	assert(result.error.message:find("ca-bundle", 1, true))
	assert(result.error.message:find("certificate verify failed", 1, true))
end

function tests.empty_stderr_still_reports_the_transport_failure()
	local f = fixture({ { code = 35 } })
	local result = f.check()
	assert(result.error.code == "network")
	assert(result.error.message:find("TLS handshake failed", 1, true))
	assert(not result.error.message:find("Details:", 1, true))
end

function tests.oversized_stderr_cannot_expose_a_partial_token()
	local f = fixture({ { code = 35, detail = string.rep("x", 8180) .. TOKEN } })
	local result = f.check()
	assert(result.error.code == "network")
	assert(#result.error.message < 300)
	assert(not result.error.message:find("test-token", 1, true))
end

function tests.successful_api_responses_are_not_corrupted_by_stderr()
	local responses = {}
	for _, body in ipairs({ "empty", "zone", "empty", "empty", "local web page" }) do
		responses[#responses + 1] = { body = body, status = "200", detail = "diagnostic on stderr\n" }
	end
	local f = fixture(responses)
	local result = f.check()
	assert(not result.error and result.checked)
	assert(result.zone == "example.com" and result.origin == "http://127.0.0.1:80")
	assert(#f.calls == 5)
end

function tests.http_permission_errors_remain_distinct_from_tls_failures()
	local f = fixture({ { status = "403", detail = "diagnostic on stderr\n" } })
	assert(f.check().error.code == "permission_zone")
end

local count = 0
for name, test in pairs(tests) do
	local ok, err = pcall(test)
	if not ok then io.stderr:write(name .. ": " .. tostring(err) .. "\n"); os.exit(1) end
	count = count + 1
end
print(string.format("%d runtime tests passed", count))

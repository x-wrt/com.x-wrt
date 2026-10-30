-- Run with Lua 5.1. No network access or router configuration is changed.
local here = arg[0]:match("^(.*)/[^/]+$") or "."
package.path = here .. "/../root/usr/lib/lua/?.lua;" .. package.path
local core = require "cloudflare_tunnel.core"
local ZONE, ACCOUNT = string.rep("1", 32), string.rep("2", 32)
local DEVICE = "aabbcc112233"
local TOKEN = string.rep("test-token-", 5)

local function clone(v)
	if type(v) ~= "table" then return v end
	local out = {}; for k, item in pairs(v) do out[k] = clone(item) end; return out
end

local function equal(a, b, message)
	assert(a == b, (message or "values differ") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

local function raises(fn, code)
	local ok, err = pcall(fn)
	assert(not ok, "expected error " .. code)
	assert(type(err) == "table", tostring(err))
	equal(err.code, code)
end

local function fixture()
	local f = {
		zones = { { id = ZONE, name = "example.com", status = "active", account = { id = ACCOUNT } } },
		tunnels = {}, records = {}, configurations = {}, state = {}, calls = {},
		created_tunnels = 0, created_dns = 0, deleted_dns = 0, activated = 0, saved = 0
	}
	function f.api(method, path, body, scope)
		f.calls[#f.calls + 1] = { method = method, path = path, body = clone(body), scope = scope }
		if f.reject_scope == scope then core.fail("permission_" .. scope, "permission denied") end
		if f.reject_method == method and f.reject_path and path:find(f.reject_path, 1, true) then core.fail("permission_" .. scope, "permission denied") end
		if path:match("^/zones%?name=") then
			local name = path:match("name=([^&]+)"); local out = {}
			for _, zone in ipairs(f.zones) do if zone.name == name then out[#out + 1] = clone(zone) end end
			return out
		end
		local aid, tid = path:match("^/accounts/(%x+)/cfd_tunnel/([%x%-]+)")
		if path:match("/configurations$") then
			if method == "GET" then return { config = clone(f.configurations[tid] or {}) } end
			f.configurations[tid] = clone(body.config); return clone(body)
		elseif path:match("/token$") then return "connector-token-" .. tid
		elseif path:find("/cfd_tunnel", 1, true) then
			aid = path:match("/accounts/(%x+)/")
			if method == "GET" then
				local out, name = {}, path:match("[?&]name=([^&]+)")
				for _, item in pairs(f.tunnels) do if item.account_id == aid and item.name == name then out[#out + 1] = clone(item) end end
				return out
			end
			if method == "POST" then
				f.created_tunnels = f.created_tunnels + 1
				local tunnel = { id = string.format("00000000-0000-4000-8000-%012d", f.created_tunnels), name = body.name,
					account_id = aid, remote_config = true, token = "connector-token-created" }
				f.tunnels[tunnel.id] = clone(tunnel)
				if f.lose_tunnel_response then f.lose_tunnel_response = false; core.fail("network", "response lost after create") end
				return tunnel
			end
		end
		local zid = path:match("^/zones/(%x+)/dns_records")
		if zid then
			local rid = path:match("/dns_records/(%x+)$")
			if method == "GET" then
				if rid then return clone(f.records[rid]) end
				local out, name = {}, path:match("[?&]name=([^&]+)")
				for _, record in pairs(f.records) do if record.zone_id == zid and record.name == name then out[#out + 1] = clone(record) end end
				return out
			elseif method == "POST" then
				f.created_dns = f.created_dns + 1
				local record = clone(body); record.id = string.format("%032x", f.created_dns); record.zone_id = zid
				f.records[record.id] = clone(record)
				if f.lose_dns_response then f.lose_dns_response = false; core.fail("network", "response lost after DNS create") end
				return record
			elseif method == "DELETE" then
				assert(f.records[rid], "deleting unknown record"); f.records[rid] = nil; f.deleted_dns = f.deleted_dns + 1; return { id = rid }
			elseif method == "PATCH" then
				f.records[rid].proxied = body.proxied; return clone(f.records[rid])
			end
		end
		error("unexpected API call " .. method .. " " .. path)
	end
	f.ctx = {
		api = f.api, device_id = DEVICE,
		origin = function() return "http://127.0.0.1:80" end,
		progress = function(stage) f.stage = stage end,
		save = function(state) f.saved = f.saved + 1; f.persisted = clone(state) end,
		activate = function(token)
			assert(token:match("^connector%-token")); f.activated = f.activated + 1
		end,
		verify = function() return { connected = true, https_ok = true } end,
		time = function() return 1000 end
	}
	function f.deploy(hostname)
		return core.deploy(f.ctx, core.settings({ hostname = hostname or "router.example.com", api_token = TOKEN }), f.state)
	end
	return f
end

local tests = {}
function tests.checks_the_web_account_password_instead_of_ssh_root()
	local shadow = { root = "", admin = "$6$example-admin-hash" }
	local function lookup(user) return shadow[user] end
	assert(core.web_passwords_set({ {username = "admin", password = "$p$admin"} }, lookup))
	shadow.root, shadow.admin = "$6$example-root-hash", ""
	assert(not core.web_passwords_set({ {username = "admin", password = "$p$admin"} }, lookup))
	assert(core.web_passwords_set({ {username = "root", password = "$p$root"} }, lookup))
	assert(core.web_passwords_set({ {username = "admin", password = "$p$root"} }, lookup))
	assert(not core.web_passwords_set({ {username = "admin", password = ""} }, lookup))
	assert(not core.web_passwords_set({ {username = "admin", password = "$p$missing"} }, lookup))
end
function tests.hostname_and_token_validation()
	equal(core.hostname(" ABC.Example.COM. "), "abc.example.com")
	for _, name in ipairs({ "https://abc.example.com", "*.example.com", "abc..example.com", ".abc.example.com", "-abc.example.com", "abc-.example.com", "abc.example.com/", "abc.example.com\nInjected: bad", string.rep("a", 64) .. ".example.com" }) do
		raises(function() core.hostname(name) end, "hostname")
	end
	equal(core.settings({ hostname = "abc.example.com", api_token = "" }, { api_token = TOKEN }).api_token, TOKEN)
	raises(function() core.settings({ hostname = "abc.example.com", api_token = TOKEN .. "\nInjected: bad" }) end, "token")
end

function tests.normal_deploy_and_retry_reuse_every_resource()
	local f = fixture(); local result = f.deploy()
	assert(result.connected and result.https_ok)
	equal(f.created_tunnels, 1); equal(f.created_dns, 1)
	assert(f.state.active and f.persisted.active)
	local first_id = f.state.active.tunnel_id
	f.deploy(); equal(f.created_tunnels, 1); equal(f.created_dns, 1); equal(f.state.active.tunnel_id, first_id)
	local rules = f.configurations[first_id].ingress
	equal(#rules, 2); equal(rules[2].service, "http_status:404")
end

function tests.longest_matching_zone_and_free_certificate()
	local f = fixture()
	f.zones[#f.zones + 1] = { id = string.rep("3", 32), name = "devices.example.com", status = "active", account = { id = ACCOUNT } }
	f.deploy("router.devices.example.com")
	equal(f.state.active.zone_id, string.rep("3", 32))
	local g = fixture()
	raises(function() g.deploy("router.deep.example.com") end, "certificate")
	equal(g.created_tunnels, 0); equal(g.created_dns, 0)
	raises(function() g.deploy("example.com") end, "hostname")
end

function tests.missing_zone_or_dns_scope_does_not_create_tunnel()
	local f = fixture(); raises(function() f.deploy("router.invalid.example") end, "zone")
	equal(f.created_tunnels, 0)
	f.reject_scope = "dns"; raises(function() f.deploy() end, "permission_dns")
	equal(f.created_tunnels, 0); equal(f.created_dns, 0)
	f.reject_scope = "tunnel"; raises(function() f.deploy() end, "permission_tunnel")
	equal(f.created_tunnels, 0)
end

function tests.conflicting_dns_never_overwritten()
	local f = fixture()
	f.records[string.rep("a", 32)] = { id = string.rep("a", 32), zone_id = ZONE, name = "router.example.com", type = "A", content = "192.0.2.1" }
	raises(function() f.deploy() end, "conflict")
	equal(f.created_tunnels, 0); equal(f.deleted_dns, 0)
end

function tests.untracked_named_tunnel_is_not_taken_over()
	local f = fixture()
	f.tunnels["existing"] = { id = "00000000-0000-4000-8000-000000000099", name = "xwrt-" .. DEVICE, account_id = ACCOUNT, remote_config = true }
	raises(function() f.deploy() end, "conflict")
	equal(f.created_tunnels, 0); equal(f.activated, 0)
end

function tests.failed_dns_write_keeps_tunnel_for_retry()
	local f = fixture(); f.reject_method = "POST"; f.reject_path = "/dns_records"
	raises(function() f.deploy() end, "permission_dns")
	equal(f.created_tunnels, 1); equal(f.activated, 0)
	f.state = clone(f.persisted); f.reject_method = nil
	f.deploy(); equal(f.created_tunnels, 1); equal(f.created_dns, 1)
end

function tests.lost_tunnel_creation_response_is_reconciled()
	local f = fixture(); f.lose_tunnel_response = true
	raises(function() f.deploy() end, "network")
	assert(f.persisted.tunnels[ACCOUNT].pending)
	f.state = clone(f.persisted); f.deploy()
	equal(f.created_tunnels, 1); equal(f.created_dns, 1)
end

function tests.lost_dns_creation_response_is_reconciled_and_owned()
	local f = fixture(); f.lose_dns_response = true
	raises(function() f.deploy() end, "network")
	f.state = clone(f.persisted); f.deploy()
	equal(f.created_dns, 1)
	f.deploy("new.example.com")
	equal(f.deleted_dns, 1)
end

function tests.route_failure_preserves_dns_for_retry()
	local f = fixture(); f.reject_method = "PUT"; f.reject_path = "/configurations"
	raises(function() f.deploy() end, "permission_tunnel")
	equal(f.created_tunnels, 1); equal(f.created_dns, 1); equal(f.activated, 0)
	f.state = clone(f.persisted); f.reject_method = nil; f.deploy()
	equal(f.created_tunnels, 1); equal(f.created_dns, 1)
end

function tests.rename_removes_only_owned_dns_and_preserves_other_routes()
	local f = fixture(); f.deploy(); local tid = f.state.active.tunnel_id
	table.insert(f.configurations[tid].ingress, 1, { hostname = "other.example.com", service = "http://127.0.0.1:8080" })
	f.deploy("new.example.com")
	equal(f.created_tunnels, 1); equal(f.created_dns, 2); equal(f.deleted_dns, 1)
	local rules = f.configurations[tid].ingress
	equal(#rules, 3); equal(rules[1].hostname, "other.example.com"); equal(rules[2].hostname, "new.example.com")
end

function tests.externally_modified_old_dns_is_not_deleted()
	local f = fixture(); f.deploy()
	f.records[f.state.active.dns_id].content = "someone-else.example.com"
	f.deploy("new.example.com"); equal(f.deleted_dns, 0)
end

function tests.external_identical_dns_is_reused_but_never_claimed()
	local f = fixture(); f.deploy()
	local record = f.records[f.state.active.dns_id]
	f.state.dns = {}; f.state.active = nil
	f.deploy(); equal(f.created_dns, 1)
	f.deploy("new.example.com"); equal(f.deleted_dns, 0)
	assert(f.records[record.id])
end

function tests.account_change_uses_a_separate_tunnel()
	local f = fixture(); f.deploy(); local first = f.state.active.tunnel_id
	f.zones[#f.zones + 1] = { id = string.rep("4", 32), name = "another.example", status = "active", account = { id = string.rep("5", 32) } }
	f.deploy("router.another.example")
	equal(f.created_tunnels, 2); assert(f.state.active.tunnel_id ~= first)
	assert(f.state.tunnels[ACCOUNT] and f.state.tunnels[string.rep("5", 32)])
end

function tests.https_pending_is_reported_without_losing_resources()
	local f = fixture(); f.ctx.verify = function() return { connected = true, https_ok = false } end
	local result = f.deploy(); assert(result.connected and not result.https_ok)
	assert(f.persisted.active and not f.persisted.https_ok)
end

function tests.device_b_rename_does_not_delete_device_a_records()
	-- Two routers share the same Cloudflare account and API transport, while
	-- each has its own persisted ownership database and stable device ID.
	local cloud = fixture()
	local a_state, b_state = {}, {}
	local function context(device)
		local ctx = clone(cloud.ctx)
		ctx.device_id = device
		return ctx
	end
	local a, b = context("aaaaaaaaaaaa"), context("bbbbbbbbbbbb")
	local function deploy(ctx, state, host)
		return core.deploy(ctx, core.settings({ hostname = host, api_token = TOKEN }), state)
	end
	deploy(a, a_state, "aa.example.com")
	local a_id, a_target = a_state.active.dns_id, a_state.active.tunnel_id .. ".cfargotunnel.com"
	deploy(b, b_state, "bb.example.com")
	local old_b = b_state.active.dns_id
	deploy(b, b_state, "bb2.example.com")
	assert(cloud.records[a_id], "B deleted A's record")
	equal(cloud.records[a_id].name, "aa.example.com")
	equal(cloud.records[a_id].content, a_target)
	assert(not cloud.records[old_b], "B did not clean its own previous record")
	equal(cloud.deleted_dns, 1)
	equal(cloud.created_tunnels, 2)
	assert(a_state.active.tunnel_id ~= b_state.active.tunnel_id)
	-- B also cannot take A's existing hostname over during a later deployment.
	raises(function() deploy(b, b_state, "aa.example.com") end, "conflict")
	equal(cloud.records[a_id].content, a_target)
end

function tests.dns_cache_notice_survives_deployment()
	local f = fixture()
	f.ctx.verify = function() return { connected = true, https_ok = true, dns_cache_pending = true } end
	local result = f.deploy()
	assert(result.dns_cache_pending and f.persisted.dns_cache_pending)
end

local count = 0
for name, test in pairs(tests) do
	local ok, err = pcall(test)
	if not ok then io.stderr:write("FAIL " .. name .. ": " .. (type(err) == "table" and (err.code .. ": " .. err.message) or tostring(err)) .. "\n"); os.exit(1) end
	count = count + 1
	print("PASS " .. name)
end
print(string.format("%d deployment tests passed", count))

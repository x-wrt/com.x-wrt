-- Copyright (C) 2019 X-WRT <dev@x-wrt.com>

module("luci.controller.natcap", package.seeall)

local ut = require "luci.util"
local sys  = require "luci.sys"
local http = require "luci.http"
local js = require "cjson.safe"

function index()
	if not nixio.fs.access("/etc/config/natcapd") then
		return
	end

	local uci = require "luci.model.uci".cursor()
	local ui = uci:get("natcapd", "default", "ui") or ""

	local page

	if ui == "world" or ui == "simple" then
		page = entry({"admin", "services", "natcap"}, cbi("natcap/natcap"), _("NATCAP"))
		page.i18n = "natcap"
		page.dependent = true
		page.acl_depends = { "luci-app-natcap" }
	elseif ui == "sdwan" then
		page = entry({"admin", "natcap_sdwan"}, firstchild(), _("SD-WAN"), 60)
		page.dependent = false
		page.acl_depends = { "luci-app-natcap" }
		page = entry({"admin", "natcap_sdwan", "basic"}, cbi("natcap/natcap_sdwan"), _("Basic Settings"))
		page.i18n = "natcap"
		page.dependent = true
		page.acl_depends = { "luci-app-natcap" }
		page = node("admin", "natcap_sdwan", "activation")
		page.target = template("natcap/natcap_sdwan")
		page.title  = _("Top Up")
		page = entry({"admin", "natcap_sdwan", "activation_sn"}, post("activation_sn"), nil)
		page.leaf = true
		page.acl_depends = { "luci-app-natcap" }
	else
		page = entry({"admin", "services", "natcap"}, cbi("natcap/natcap_simple"), _("NATCAP"))
		page.i18n = "natcap"
		page.dependent = true
		page.acl_depends = { "luci-app-natcap" }
	end

	entry({"admin", "services", "natcap", "get_natcap_flows0"}, call("get_natcap_flows0")).leaf = true
	entry({"admin", "services", "natcap", "get_natcap_flows1"}, call("get_natcap_flows1")).leaf = true

	local vpn_clients = {
		{ name = "get_openvpn_client", action = "gen_client", filename = "natcap-client-tcp.ovpn" },
		{ name = "get_openvpn_client_udp", action = "gen_client_udp", filename = "natcap-client-udp.ovpn" },
		{ name = "get_openvpn_client6", action = "gen_client6", filename = "natcap-client-tcp6.ovpn" },
		{ name = "get_openvpn_client6_udp", action = "gen_client6_udp", filename = "natcap-client-udp6.ovpn" },
	}

	for _, v in ipairs(vpn_clients) do
		entry({"admin", "services", "natcap", v.name}, call("get_openvpn_client_handler")).leaf = true
	end

	entry({"admin", "services", "natcap", "status"}, call("status")).leaf = true
	entry({"admin", "services", "natcap", "change_server"}, call("change_server")).leaf = true

	page = entry({"admin", "vpn", "natcapd_vpn"}, cbi("natcap/natcapd_vpn"), _("One-click VPN"))
	page.i18n = "natcap"
	page.dependent = true
	page.acl_depends = { "luci-app-natcap" }

	page = entry({"admin", "system", "natcapd_sys"}, cbi("natcap/natcapd_sys"), _("Advanced Options"))
	page.i18n = "natcap"
	page.dependent = true
	page.acl_depends = { "luci-app-natcap" }

	if ui == "simple" then
		page = entry({"admin", "natcap_route"}, cbi("natcap/natcap_route"), _("Route Settings"))
		page.i18n = "natcap"
		page.dependent = true
		page.acl_depends = { "luci-app-natcap" }
	elseif ui == "world" then
		page = entry({"admin", "services", "natcap_route"}, cbi("natcap/natcap_route"), _("Route Settings"))
		page.i18n = "natcap"
		page.dependent = true
		page.acl_depends = { "luci-app-natcap" }
	end
end

function activation_sn(sn)
	local reader = ltn12_popen("/usr/sbin/natcapd activation_sn %s" % ut.shellquote(sn))

	http.prepare_content("text/plain")
	luci.ltn12.pump.all(reader, http.write)
	return
end

function status()
	local text = nixio.fs.readfile("/dev/natcap_ctl") or ""
	local oldtxrx = nixio.fs.readfile("/tmp/natcapd.txrx") or ""
	local flows = nixio.fs.readfile("/tmp/xx.json") or ""

	local oldtx, oldrx = oldtxrx:match("(%w+) (%w+)")

	local data = {
		cur_server = text:match("current_server0=(.-)\n"),
		uhash = text:match("u_hash=(.-)\n"),
		client_mac = text:match("default_mac_addr=([%x:]+)\n"),
		total_tx = text:match("flow_total_tx_bytes=(.-)\n"),
		total_rx = text:match("flow_total_rx_bytes=(.-)\n"),
	}
	data.total_tx = tonumber(data.total_tx) or 0
	data.total_rx = tonumber(data.total_rx) or 0
	if data.client_mac then
		data.client_mac = data.client_mac:gsub(":", "")
		data.uid = data.client_mac .. "-" .. (data.uhash or "")
		data.mgr = "https://" .. string.lower(data.client_mac) .. ".x-wrt.dev/"
		data.domain = string.lower(data.client_mac) .. ".dns.x-wrt.com"
	end
	data.client_mac = nil
	data.uhash = nil
	data.flows = js.decode(flows) or {}
	data.flows = data.flows.flows
	if data.flows and data.flows[1] then
		data.flows[1].tx = tonumber(data.flows[1].tx) + data.total_tx - (tonumber(oldtx) or 0)
		data.flows[1].rx = tonumber(data.flows[1].rx) + data.total_rx - (tonumber(oldrx) or 0)
	end

	local yy = nixio.fs.readfile("/tmp/yy.json") or ""
	yy = js.decode(yy) or {}
	data.exp = os.date('%Y-%m-%d %H:%M:%S', yy.data and yy.data.exp or 0)

	http.prepare_content("application/json")
	http.write_json(data)
end

function change_server()
	nixio.fs.writefile("/dev/natcap_ctl", "change_server\n")

	local text = nixio.fs.readfile("/dev/natcap_ctl") or ""
	local data = {
		cur_server = text:match("current_server0=(.-)\n"),
	}

	http.prepare_content("application/json")
	http.write_json(data)
end

local function handle_get_flows(action, from_date, to_date)
	local filename = string.format("Flows_%s-%s", from_date, to_date)
	local reader = ltn12_popen(string.format("/usr/sbin/natcapd %s", action))

	http.header('Content-Disposition', 'attachment; filename="' .. filename .. '.csv"')
	http.prepare_content("text/csv; charset=UTF-8")
	luci.ltn12.pump.all(reader, http.write)
end

function get_natcap_flows0()
	local now = os.date("*t")
	local from = os.date("%Y%m%d", os.time({year=now.year, month=now.month, day=1}))
	local to = os.date("%Y%m%d")
	handle_get_flows("get_flows0", from, to)
end

function get_natcap_flows1()
	local now = os.date("*t")
	local from = os.date("%Y%m%d", os.time({year=now.year, month=now.month-1, day=1}))
	local to = os.date("%Y%m%d", os.time({year=now.year, month=now.month, day=0}))
	handle_get_flows("get_flows1", from, to)
end

function get_openvpn_client_handler()
	local req = luci.dispatcher.context.requestpath
	local req_name = req[#req]

	local vpn_clients = {
		get_openvpn_client = { action = "gen_client", filename = "natcap-client-tcp.ovpn" },
		get_openvpn_client_udp = { action = "gen_client_udp", filename = "natcap-client-udp.ovpn" },
		get_openvpn_client6 = { action = "gen_client6", filename = "natcap-client-tcp6.ovpn" },
		get_openvpn_client6_udp = { action = "gen_client6_udp", filename = "natcap-client-udp6.ovpn" },
	}

	local client = vpn_clients[req_name]
	if client then
		local reader = ltn12_popen("sh /usr/share/natcapd/natcapd.openvpn.sh " .. client.action)
		http.header('Content-Disposition', 'attachment; filename="' .. client.filename .. '"')
		http.prepare_content("application/x-openvpn-profile")
		luci.ltn12.pump.all(reader, http.write)
	end
end

function ltn12_popen(command)
	local fdi, fdo = nixio.pipe()
	local pid = nixio.fork()

	if pid > 0 then
		fdo:close()
		local close
		return function()
			local buffer = fdi:read(2048)
			local wpid, stat = nixio.waitpid(pid, "nohang")
			if not close and wpid and stat == "exited" then
				close = true
			end

			if buffer and #buffer > 0 then
				return buffer
			elseif close then
				fdi:close()
				return nil
			end
		end
	elseif pid == 0 then
		nixio.dup(fdo, nixio.stdout)
		fdi:close()
		fdo:close()
		nixio.exec("/bin/sh", "-c", command)
	end
end

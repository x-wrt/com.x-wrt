-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.natcap", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/natcapd") then
		return
	end

	local page

	page = entry({"admin", "services", "natcap"}, cbi("natcap/natcap"), _("Natcap"))
	page.i18n = "natcap"
	page.dependent = true

	entry({"admin", "services", "natcap", "status"}, call("status")).leaf = true
	entry({"admin", "services", "natcap", "change_server"}, call("change_server")).leaf = true
end

function status()
	local ut = require "luci.util"
	local sys  = require "luci.sys"
	local http = require "luci.http"
	local js = require "cjson.safe"

	local text = ut.trim(sys.exec("cat /dev/natcap_ctl"))
	local oldtxrx = ut.trim(sys.exec("cat /tmp/natcapd.txrx"))
	local flows = sys.exec("cat /tmp/xx.sh")

	local oldtx = oldtxrx:gsub("(%w+) (%w+)", "%1")
	local oldrx = oldtxrx:gsub("(%w+) (%w+)", "%2")

	local data = {
		cur_server = text:gsub(".*current_server=(.-)\n.*", "%1"),
		uhash = text:gsub(".*default_u_hash=(.-)\n.*", "%1"),
		client_mac = text:gsub(".*default_mac_addr=(..):(..):(..):(..):(..):(..)\n.*", "%1%2%3%4%5%6"),
		total_tx = text:gsub(".*flow_total_tx_bytes=(.-)\n.*", "%1"),
		total_rx = text:gsub(".*flow_total_rx_bytes=(.-)\n.*", "%1"),
	}
	data.total_tx = tonumber(data.total_tx)
	data.total_rx = tonumber(data.total_rx)
	data.uid = data.client_mac .. "-" .. data.uhash
	data.domain = string.lower(data.client_mac) .. ".dns.ptpt52.com"
	data.client_mac = nil
	data.uhash = nill
	data.flows = js.decode(flows) or {}
	data.flows = data.flows.flows
	if data.flows and data.flows[1] then
		data.flows[1].tx = tonumber(data.flows[1].tx) + data.total_tx - tonumber(oldtx)
		data.flows[1].rx = tonumber(data.flows[1].rx) + data.total_rx - tonumber(oldrx)
	end

	http.prepare_content("application/json")
	http.write_json(data)
end

function change_server()
	local ut = require "luci.util"
	local sys  = require "luci.sys"
	local http = require "luci.http"

	sys.call("echo change_server >/dev/natcap_ctl")

	local text = ut.trim(sys.exec("cat /dev/natcap_ctl"))
	local data = {
		cur_server = text:gsub(".*current_server=(.-)\n.*", "%1"),
	}

	http.prepare_content("application/json")
	http.write_json(data)
end

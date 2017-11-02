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
end

function status()
	local ut = require "luci.util"
	local sys  = require "luci.sys"
	local http = require "luci.http"

	local text = ut.trim(sys.exec("cat /dev/natcap_ctl"))

	local data = {
		cur_server = text:gsub(".*current_server=(.-)\n.*", "%1"),
		uhash = text:gsub(".*default_u_hash=(.-)\n.*", "%1"),
		client_mac = text:gsub(".*default_mac_addr=(..):(..):(..):(..):(..):(..)\n.*", "%1%2%3%4%5%6"),
		total_rx = text:gsub(".*flow_total_rx_bytes=(.-)\n.*", "%1"),
		total_tx = text:gsub(".*flow_total_tx_bytes=(.-)\n.*", "%1"),
	}
	data.total_rx = tonumber(data.total_rx)
	data.total_tx = tonumber(data.total_tx)
	data.uid = data.client_mac .. "-" .. data.uhash
	data.client_mac = nil
	data.uhash = nill

	if data.total_rx >= 1024*1024*1024*1024 then
		data.total_rx = string.format('<span title="%u B">%u TB</span>', data.total_rx, data.total_rx / (1024*1024*1024*1024))
	elseif data.total_rx >= 1024*1024*1024 then
		data.total_rx = string.format('<span title="%u B">%u GB</span>', data.total_rx, data.total_rx / (1024*1024*1024))
	elseif data.total_rx >= 1024*1024 then
		data.total_rx = string.format('<span title="%u B">%u MB</span>', data.total_rx, data.total_rx / (1024*1024))
	elseif data.total_rx >= 1024 then
		data.total_rx = string.format('<span title="%u B">%u KB</span>', data.total_rx, data.total_rx / (1024))
	else
		data.total_rx = string.format('<span title="%u B">%u B</span>', data.total_rx, data.total_rx)
	end

	if data.total_tx >= 1024*1024*1024*1024 then
		data.total_tx = string.format('<span title="%u B">%u TB</span>', data.total_tx, data.total_tx / (1024*1024*1024*1024))
	elseif data.total_tx >= 1024*1024*1024 then
		data.total_tx = string.format('<span title="%u B">%u GB</span>', data.total_tx, data.total_tx / (1024*1024*1024))
	elseif data.total_tx >= 1024*1024 then
		data.total_tx = string.format('<span title="%u B">%u MB</span>', data.total_tx, data.total_tx / (1024*1024))
	elseif data.total_tx >= 1024 then
		data.total_tx = string.format('<span title="%u B">%u KB</span>', data.total_tx, data.total_tx / (1024))
	else
		data.total_tx = string.format('<span title="%u B">%u B</span>', data.total_tx, data.total_tx)
	end

	http.prepare_content("application/json")
	http.write_json(data)
end

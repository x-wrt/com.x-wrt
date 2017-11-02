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

	local data = {
		cur_server = ut.trim(sys.exec("cat /dev/natcap_ctl | grep current_server= | cut -d= -f2")),
		uhash = ut.trim(sys.exec("cat /dev/natcap_ctl | grep default_u_hash= | cut -d= -f2")),
		total_rx = tonumber(ut.trim(sys.exec("cat /dev/natcap_ctl | grep flow_total_rx_bytes= | cut -d= -f2"))),
		total_tx = tonumber(ut.trim(sys.exec("cat /dev/natcap_ctl | grep flow_total_tx_bytes= | cut -d= -f2"))),
	}

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

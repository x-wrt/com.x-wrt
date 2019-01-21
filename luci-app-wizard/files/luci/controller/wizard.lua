-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.wizard", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/wizard") then
		return
	end

	local page

	page = entry({"admin", "initsetup"}, cbi("wizard/wizard"), _("Inital Setup"))
	page.i18n = "wizard"
	page.dependent = true
end

-- Copyright 2019 X-WRT <dev@x-wrt.com>

module("luci.controller.xwan", package.seeall)

function index()
	local page

	page = entry({"admin", "network", "xwan"}, cbi("xwan/xwan"), _("Multi-WAN Dialing"))
	page.leaf = true
	page.acl_depends = { "luci-app-xwan" }
end

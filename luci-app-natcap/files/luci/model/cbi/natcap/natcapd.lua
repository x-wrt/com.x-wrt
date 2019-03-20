-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008-2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

local nt = require "luci.sys".net

local m = Map("natcapd", luci.util.pcdata(translate("Basic System")), translate("The basic system settings && services"))

m:section(SimpleSection).template  = "natcap/natcapd"

local s = m:section(TypedSection, "natcapd", "")
s.addremove = false
s.anonymous = true

s:tab("system", translate("System Settings"))

e = s:taboption("system", Flag, "full_cone_nat", translate("Full Cone Nat"), translate("Generally do not need to be enabled unless used to play games."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("system", Flag, "enable_natflow", translate("Enable Fast Forwarding"))
e.default = e.disabled
e.rmempty = false

e = s:taboption("system", Flag, "natcapovpn", translate("Enable OpenVPN Server"), translate("Allows you to use OpenVPN to connect to router, the router need to have a public IP."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("system", Flag, "pptpd", translate("Enable The PPTP Server"), translate("Allows you to use VPN to connect to router, the router need to have a public IP."))
e.default = e.disabled
e.rmempty = false

local u = m:section(TypedSection, "pptpuser", "")
u.addremove = true
u.anonymous = true
u.template = "cbi/tblsection"

e = u:option(Value, "username", translate("PPTP Username"))
e.datatype = "string"
e.rmempty  = false

e = u:option(Value, "password", translate("Password"))
e.datatype = "string"
e.rmempty  = false

return m

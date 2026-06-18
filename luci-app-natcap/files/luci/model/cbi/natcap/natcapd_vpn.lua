-- Copyright 2019 X-WRT <dev@x-wrt.com>

local nt = require "luci.sys".net

local m = Map("natcapd", translate("One-click VPN"))

m:section(SimpleSection).template  = "natcap/natcapd"

local s = m:section(TypedSection, "natcapd", "")
s.addremove = false
s.anonymous = true

s:tab("system", translate("System Settings"))

if nixio.fs.access("/usr/sbin/openvpn") then
	e = s:taboption("system", Flag, "natcapovpn", translate("Enable OpenVPN Server"), translate("Allow VPN connections to this router. The router must have a public IP address."))
	e.default = e.disabled
	e.rmempty = false

	e = s:taboption("system", Flag, "natcapovpn_tap", translate("OpenVPN TAP Mode"), translate("Use OpenVPN TAP mode."))
	e.default = e.disabled
	e.rmempty = false

	e = s:taboption("system", Flag, "natcapovpn_ip6", translate("Enable OpenVPN IPv6 Server"), translate("Enable the IPv6 OpenVPN server."))
	e.default = e.disabled
	e.rmempty = false
end

e = s:taboption("system", Flag, "pptpd", translate("Enable PPTP Server"), translate("Allow VPN connections to this router. The router must have a public IP address."))
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

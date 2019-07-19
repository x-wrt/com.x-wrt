-- Copyright 2019 X-WRT <dev@x-wrt.com>

local nt = require "luci.sys".net
local uci = require("luci.model.uci").cursor()

local has_wifi = false
uci:foreach("wireless", "wifi-device",
		function(s)
			has_wifi = true
			return false
		end)

local m = Map("wizard", luci.util.pcdata(translate("Inital Router Setup")), translate("If you are using this router for the first time, please configure it here."))

local s = m:section(TypedSection, "wizard", "")
s.addremove = false
s.anonymous = true

s:tab("wansetup", translate("Wan Settings"), translate("Three different ways to access the Internet, please choose according to your own situation."))
if has_wifi then
	s:tab("wifisetup", translate("Wireless Settings"), translate("Set the router's wireless name and password. For more advanced settings, please go to the Network-Wireless page."))
end
s:tab("lansetup", translate("Lan Settings"))

local e = s:taboption("wansetup", ListValue, "wan_proto", translate("Protocol"))
e:value("dhcp", translate("DHCP client"))
e:value("static", translate("Static address"))
e:value("pppoe", translate("PPPoE"))

e = s:taboption("wansetup", Value, "wan_pppoe_user", translate("PAP/CHAP username"))
e:depends({wan_proto="pppoe"})

e = s:taboption("wansetup", Value, "wan_pppoe_pass", translate("PAP/CHAP password"))
e:depends({wan_proto="pppoe"})
e.password = true

e = s:taboption("wansetup", Value, "wan_ipaddr", translate("IPv4 address"))
e:depends({wan_proto="static"})
e.datatype = "ip4addr"

e = s:taboption("wansetup", Value, "wan_netmask", translate("IPv4 netmask"))
e:depends({wan_proto="static"})
e.datatype = "ip4addr"
e:value("255.255.255.0")
e:value("255.255.0.0")
e:value("255.0.0.0")

e = s:taboption("wansetup", Value, "wan_gateway", translate("IPv4 gateway"))
e:depends({wan_proto="static"})
e.datatype = "ip4addr"

e = s:taboption("wansetup", DynamicList, "wan_dns", translate("Use custom DNS servers"))
e:depends({wan_proto="dhcp"})
e:depends({wan_proto="static"})
e.datatype = "ip4addr"
e.cast = "string"

if has_wifi then
	e = s:taboption("wifisetup", Value, "wifi_ssid", translate("<abbr title=\"Extended Service Set Identifier\">ESSID</abbr>"))
	e.datatype = "maxlength(32)"

	e = s:taboption("wifisetup", Value, "wifi_key", translate("Key"))
	e.datatype = "wpakey"
	e.password = true
end --has_wifi

e = s:taboption("lansetup", Value, "lan_ipaddr", translate("IPv4 address"))
e.datatype = "ip4addr"

e = s:taboption("lansetup", Value, "lan_netmask", translate("IPv4 netmask"))
e.datatype = "ip4addr"
e:value("255.255.255.0")
e:value("255.255.0.0")
e:value("255.0.0.0")

return m

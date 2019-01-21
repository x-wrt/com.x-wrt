-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008-2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

local nt = require "luci.sys".net

local m = Map("wizard", luci.util.pcdata(translate("Inital Router Setup")), translate("If you are using this router for the first time, please configure it here."))

local s = m:section(TypedSection, "wizard", "")
s.addremove = false
s.anonymous = true

s:tab("wansetup", translate("Wan Settings"), translate("Three different ways to access the Internet, please choose according to your own situation."))
s:tab("wifisetup", translate("Wireless Settings"), translate("Set the router's wireless name and password. For more advanced settings, please go to the Network-Wireless page."))
s:tab("lansetup", translate("Lan Settings"))

e = s:taboption("wansetup", ListValue, "wan_proto", translate("Protocol"))
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
e:depends({wan_proto="pppoe"})
e.datatype = "ip4addr"
e.cast = "string"

e = s:taboption("wifisetup", Value, "wifi_ssid", translate("<abbr title=\"Extended Service Set Identifier\">ESSID</abbr>"))
e.datatype = "maxlength(32)"
e.rmempty = true

e = s:taboption("wifisetup", Value, "wifi_key", translate("Key"))
e.datatype = "wpakey"
e.rmempty = true
e.password = true

e = s:taboption("lansetup", Value, "lan_ipaddr", translate("IPv4 address"))
e.datatype = "ip4addr"

e = s:taboption("lansetup", Value, "lan_netmask", translate("IPv4 netmask"))
e.datatype = "ip4addr"
e:value("255.255.255.0")
e:value("255.255.0.0")
e:value("255.0.0.0")

return m

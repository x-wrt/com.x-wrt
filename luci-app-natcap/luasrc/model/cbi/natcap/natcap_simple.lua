-- Copyright 2019 X-WRT <dev@x-wrt.com>

local nt = require "luci.sys".net

local m = Map("natcapd", translate("NATCAP Service"))

m:section(SimpleSection).template  = "natcap/natcap"

local s = m:section(TypedSection, "natcapd", "")
s.addremove = false
s.anonymous = true

s:tab("general", translate("General Settings"))
s:tab("proxyiplist", translate("Client Full Proxy"))
s:tab("macfilter", translate("MAC Filter"))
s:tab("ipfilter", translate("IP Filter"))
s:tab("bypasslist", translate("Bypass List"))
s:tab("bypasslist_domain", translate("Bypass Domain List"))

e = s:taboption("general", Flag, "peer_sni_ban", translate("Disable Remote Manager"))
e.default = e.disabled
e.rmempty = false

e = s:taboption("general", Flag, "enabled", translate("Enable NATCAP"), translate("You need an authorization code to enable international network acceleration."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("general", Flag, "encode_mode", translate("Force TCP Encapsulation over UDP"), translate("Enable only if normal mode does not work."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("general", Flag, "peer_mode", translate("Peer Mode"), translate("Enable only if normal mode does not work."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("general", ListValue, "cnipwhitelist_mode", translate("Traffic Proxy Mode"))
e.default = "0"
e:value("0", translate("Smart Proxy"))
e:value("1", translate("Proxy All International Traffic"))
e:value("2", translate("Custom Proxy Rules"))
e.rmempty = false

e = s:taboption("general", Flag, "full_proxy", translate("Proxy All Traffic"), translate("Send all traffic through the proxy."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("general", Value, "ui", translate("UI Mode"))
e.rmempty = true
e.placeholder = 'none'

e = s:taboption("proxyiplist", DynamicList, "proxy_iplist", translate("Full Proxy Client List"), translate("Send traffic from these client IP addresses through the proxy, while local destinations continue to use the normal routing policy."))
e.datatype = "ipaddr"
e.placeholder = '192.168.15.100'

e = s:taboption("macfilter", ListValue, "macfilter", translate("MAC Address Filter"))
e:value("", translate("Disabled"))
e:value("allow", translate("Allowlist (clients allowed to use NATCAP)"))
e:value("deny", translate("Blocklist (clients denied NATCAP)"))

e = s:taboption("macfilter", DynamicList, "maclist", translate("MAC List"))
e.datatype = "macaddr"
nt.mac_hints(function(mac, name) e:value(mac, "%s (%s)" %{ mac, name }) end)

e = s:taboption("ipfilter", ListValue, "ipfilter", translate("IP Address Filter"))
e:value("", translate("Disabled"))
e:value("allow", translate("Allowlist (clients allowed to use NATCAP)"))
e:value("deny", translate("Blocklist (clients denied NATCAP)"))

e = s:taboption("ipfilter", DynamicList, "iplist", translate("IP List"))
e.datatype = "ipaddr"
e.placeholder = '192.168.15.0/24'

e = s:taboption("bypasslist", DynamicList, "bypasslist", translate("Bypass List"))
e.datatype = "list(string)"
e.placeholder = "1.2.3.4"

e = s:taboption("bypasslist_domain", DynamicList, "bypasslist_domain", translate("Bypass Domain List"))
e.datatype = "list(string)"
e.placeholder = "example.com"

return m

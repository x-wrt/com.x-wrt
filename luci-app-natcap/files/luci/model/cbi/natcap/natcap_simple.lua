-- Copyright 2019 X-WRT <dev@x-wrt.com>

local nt = require "luci.sys".net

local m = Map("natcapd", translate("NATCAP Service"))

m:section(SimpleSection).template  = "natcap/natcap"

local s = m:section(TypedSection, "natcapd", "")
s.addremove = false
s.anonymous = true

s:tab("general", translate("General Settings"))

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

return m

-- Copyright 2019 X-WRT <dev@x-wrt.com>

local nt = require "luci.sys".net

local m = Map("natcapd", translate("SD-WAN Service"))

m:section(SimpleSection).template  = "natcap/natcap"

local s = m:section(TypedSection, "natcapd", "")
s.addremove = false
s.anonymous = true

s:tab("general", translate("General Settings"))

e = s:taboption("general", Flag, "enabled", translate("Enable"), translate("You need an authorization code to enable international network acceleration."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("general", Flag, "encode_mode", translate("Force TCP encode as UDP"), translate("Do not enable unless the normal mode is not working."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("general", Flag, "peer_mode", translate("Peer Mode"), translate("Do not enable unless the normal mode is not working."))
e.default = e.disabled
e.rmempty = false

return m

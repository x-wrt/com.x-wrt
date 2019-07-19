-- Copyright 2019 X-WRT <dev@x-wrt.com>

local nt = require "luci.sys".net

local m = Map("natcapd", luci.util.pcdata(translate("Natcap Service")))

m:section(SimpleSection).template  = "natcap/natcap"

local s = m:section(TypedSection, "natcapd", "")
s.addremove = false
s.anonymous = true

s:tab("general", translate("General Settings"))

e = s:taboption("general", Flag, "enabled", translate("Enable Natcap"))
e.default = e.disabled
e.rmempty = false

return m

-- Copyright 2019 X-WRT <dev@x-wrt.com>
-- Licensed to the public under the Apache License 2.0.

local nt = require "luci.sys".net

local m = Map("natcapd", luci.util.pcdata(translate("System Optimization")))

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

return m

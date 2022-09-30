-- Copyright 2019 X-WRT <dev@x-wrt.com>

local ut = require "luci.util"
local sys  = require "luci.sys"
local nt = require "luci.sys".net

local m = Map("natcapd", luci.xml.pcdata(translate("Advanced Options")))

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

local has_hwnat = ut.trim(sys.exec("cat /dev/natflow_ctl | grep hwnat= 2>/dev/null"))
if has_hwnat and string.len(has_hwnat) > 0 then
	e = s:taboption("system", Flag, "enable_natflow_hw", translate("Enable Fast Forwarding Hardware Offload"))
	e.default = e.disabled
	e.rmempty = false
	e:depends("enable_natflow","1")
end

return m

-- Copyright 2019 X-WRT <dev@x-wrt.com>

local ut = require "luci.util"
local sys  = require "luci.sys"
local nt = require "luci.sys".net

local m = Map("natcapd", translate("Advanced Options"))

local s = m:section(TypedSection, "natcapd", "")
s.addremove = false
s.anonymous = true

s:tab("system", translate("System Settings"))

e = s:taboption("system", Flag, "full_cone_nat", translate("Full-cone NAT"), translate("Usually only needed for gaming or peer-to-peer applications."))
e.default = e.disabled
e.rmempty = false

e = s:taboption("system", Flag, "enable_natflow", translate("Enable NATflow Fast Forwarding"))
e.default = e.disabled
e.rmempty = false

local nixio = require "nixio"
local natflow_ctl_text = nixio.fs.readfile("/dev/natflow_ctl") or ""

local has_hwnat = string.find(natflow_ctl_text, "hwnat=")
if has_hwnat then
	e = s:taboption("system", Flag, "enable_natflow_hw", translate("Enable Hardware Flow Offload"))
	e.default = e.disabled
	e.rmempty = false
	e:depends("enable_natflow","1")
end

local has_hwnat_wed = string.find(natflow_ctl_text, "hwnat_wed_disabled=")
if has_hwnat_wed then
	e = s:taboption("system", Flag, "enable_natflow_hw_wed", translate("Enable WED Hardware Offload"))
	e.default = e.disabled
	e.rmempty = false
	e:depends("enable_natflow_hw","1")
end

return m

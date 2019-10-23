-- Copyright 2019 X-WRT <dev@x-wrt.com>

m = Map("xwan", translate("Xwan"))

s = m:section(TypedSection, "xwan", translate("Xwan Settings"))
s.addremove = false
s.anonymous = true

e = s:option(Flag, "enabled", translate("Enable xwan"), translate("multiwan on single interface"))
e.default = e.disabled
e.rmempty = false

e = s:option(Value, "number", translate("Number of xwan"))
e.datatype = "and(uinteger,min(1),max(60))"
e.rmempty  = false

e = s:option(Flag, "balanced", translate("Auto balanced setup"))
e.default = e.disabled
e.rmempty = false

return m

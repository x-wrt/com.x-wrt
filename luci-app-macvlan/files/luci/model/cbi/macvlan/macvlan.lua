-- Copyright (C) 2019 X-WRT <dev@x-wrt.com>

m = Map("macvlan", translate("Macvlan"))

s = m:section(TypedSection, "macvlan", translate("Macvlan Settings"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

hn = s:option(Value, "ifname", translate("Interface"))
hn.datatype = "string"
hn.rmempty  = false

ip = s:option(Value, "macvlan", translate("Index"))
ip.datatype = "and(uinteger,min(0),max(31))"
ip.rmempty  = false

return m

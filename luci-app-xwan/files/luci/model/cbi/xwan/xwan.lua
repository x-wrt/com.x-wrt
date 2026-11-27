-- Copyright 2019 X-WRT <dev@x-wrt.com>

m = Map("xwan", translate("Multi-WAN Dialing"))

s = m:section(TypedSection, "xwan", translate("Multi-WAN Dialing Settings"))
s.addremove = true
s.anonymous = true

e = s:option(ListValue, "interface", translate("Source WAN interface"))
m.uci:foreach("network", "interface", function(section)
	local name = section[".name"]
	local proto = section.proto
	local generated = section.xwan == "1" or name:match("^x.+%d%d$") or
		(section.device or ""):match("^mv.+%d%d$") or
		(section.ifname or ""):match("^mv.+%d%d$")
	if name ~= "loopback" and name ~= "lan" and proto ~= "dhcpv6" and not generated then
		e:value(name, name .. (section.device and " (" .. section.device .. ")" or ""))
	end
end)
e.rmempty = false
e.default = "wan"

e = s:option(Flag, "enabled", translate("Enable multi-WAN dialing"), translate("Create multiple WAN connections on a single physical interface."))
e.default = e.disabled
e.rmempty = false

e = s:option(Value, "number", translate("Number of WAN instances"))
e.datatype = "and(uinteger,min(1),max(60))"
e.rmempty  = false

e = s:option(Flag, "balanced", translate("Configure load balancing automatically"))
e.default = e.disabled
e.rmempty = false

e = s:option(DynamicList, "track_ip", translate("Health check hostnames or IP addresses"), translate("Ping these hosts to determine whether each WAN link is up. Leave empty to treat the links as always online."))
e.datatype = 'host'
e.default = ""
e.placeholder = "gateway"

e = s:option(ListValue, 'family', translate("IP family"))
e.default = ''
e:value('', translate('IPv4 and IPv6'))
e:value('ipv4', translate('IPv4'))
e:value('ipv6', translate('IPv6'))

return m

-- Copyright 2019 X-WRT <dev@x-wrt.com>

local nt = require "luci.sys".net
local ut = require "luci.util"
local sys = require "luci.sys"

local m = Map("natcapd", translate("Route Settings"), translate("Select an outbound gateway for LAN clients."))

m:section(SimpleSection).template  = "natcap/natcap"

local s = m:section(TypedSection, "natcapd", "")
s.addremove = false
s.anonymous = true

local nixio = require "nixio"
local text = nixio.fs.readfile("/dev/natcap_ctl") or ""

local function populate_targets(option)
	option:value("", translate("Please select..."))
	for ip in text:gmatch("server 0 ([0-9.]+[^\n]+)") do
		option:value(ip)
	end
end

--rulesets
local u = m:section(TypedSection, "ruleset", "")
u.addremove = true
u.anonymous = true
u.template = "cbi/tblsection"

local e = u:option(Value, "src", translate("Source Client(s)"))
e.datatype = "string"
e.rmempty  = false
e.placeholder = "192.168.15.100 or AA:00:11:23:44:55"

e = u:option(Value, "dst", translate("Destination"))
e.datatype = "string"
e.rmempty  = false
e.placeholder = "ipset name"

e = u:option(ListValue, "target", translate("Outbound Gateway"))
populate_targets(e)

--rules
u = m:section(TypedSection, "rule", "")
u.addremove = true
u.anonymous = true
u.template = "cbi/tblsection"

e = u:option(Value, "src", translate("Source Client(s)"))
e.datatype = "string"
e.rmempty  = false
e.placeholder = "192.168.15.100 or AA:00:11:23:44:55"

e = u:option(ListValue, "target", translate("Outbound Gateway"))
populate_targets(e)

return m

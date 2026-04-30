local d = io.popen(". /lib/functions/system.sh; get_mac_label")
local m = d:read("*all")
d:close()

if m and string.len(m) >= 17 then
	print(string.upper(string.sub(m, 1, 17)))
	os.exit(0)
end

local js = require "cjson"
local f = io.open("/etc/board.json", "r")
if not f then
	os.exit(0)
end
local t = f:read("*all")
f:close()

t = js.decode(t)

if t.system and t.system.label_macaddr then
	print(string.upper(t.system.label_macaddr))
	os.exit(0)
end

if t.network and t.network.wan and t.network.wan.macaddr then
	print(string.upper(t.network.wan.macaddr))
	os.exit(0)
end

if t.network and t.network.lan and t.network.lan.macaddr then
	print(string.upper(t.network.lan.macaddr))
	os.exit(0)
end

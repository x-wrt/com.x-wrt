local js = require "cjson"
local f = io.open("/tmp/yy.sn.json", "r")
if not f then
	os.exit(0)
end
local t = f:read("*all")
f:close()

t = js.decode(t)

if t.code == 0 then
	print("Success!");
	if t.exp then
		print("Expire Date: %s" % os.date('%Y-%m-%d %H:%M:%S', t.exp))
	end
else
	print("Fail!");
end

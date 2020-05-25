local js = require "cjson"
local f = io.open("/tmp/yy.json", "r")
if not f then
	os.exit(0)
end
local t = f:read("*all")
f:close()

t = js.decode(t)

if t.shell then
	local mime = require "mime"
	f = io.open("/tmp/yy.json.sh", "w+")
	if not f then os.exit(0) end
	f:write(mime.unb64(t.shell))
	f:close()
end

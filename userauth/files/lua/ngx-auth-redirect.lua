if ngx.req.get_method() ~= 'GET' then
	ngx.exit(ngx.HTTP_FORBIDDEN)
end
local st = nil
if ngx.var.host == 'captive.apple.com' then
	local rs = ngx.shared.auth_status
	local key = 'st:' .. ngx.var.remote_addr
	if rs:get(key) == 1 then
		rs:set(key, 0)
		st = 0
	else
		rs:set(key, 1)
		st = 1
	end
end
if not st or st ~= 0 then
	local args = ngx.encode_args({
			aid = ngx.var.aid,
			url = ngx.var.req_url,
			ts = ngx.time()
			})
	local redirect_url = 'http://' .. ngx.var.redirect_ip .. '/index.html?' .. args
	ngx.header.cache_control = {'private', 'no-cache'}
	return ngx.redirect(redirect_url, ngx.HTTP_MOVED_TEMPORARILY)
end

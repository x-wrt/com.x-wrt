if ngx.req.get_method() ~= 'GET' then
	ngx.exit(ngx.HTTP_FORBIDDEN)
end
if not request_need_proxypass(ngx) then
	local args = ngx.encode_args({
			aid = ngx.var.aid,
			url = ngx.var.req_url,
			ts = ngx.time()
			})
	local redirect_url = 'http://' .. ngx.var.redirect_ip .. '/index.html?' .. args
	ngx.header.cache_control = {'private', 'no-cache'}
	return ngx.redirect(redirect_url, ngx.HTTP_MOVED_TEMPORARILY)
end

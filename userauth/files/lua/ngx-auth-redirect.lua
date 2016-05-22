if ngx.req.get_method() ~= 'GET' then
	ngx.exit(ngx.HTTP_FORBIDDEN)
end
if not request_need_proxypass(ngx) then
	local data = {}
	local ua = ngx.req.get_headers()['User-Agent']
	if ua and ua:match('.*micromessenger.*') then
		local macaddr = get_client_macaddr(ngx) or 'ff:ff:ff:ff:ff:ff'
		local info = get_wechat_info(ngx.var.aid)
		if info then
			local timestamp = ngx.time() * 1000
			local sign = ngx.md5(string.format('%s%s%s%s%s%s', ngx.var.aid, ngx.var.remote_addr, macaddr, timestamp, info.ssid, info.secretKey))
			local extend = string.format('%s,%s,%s,%s,%s,%s,', ngx.var.aid, ngx.var.remote_addr, macaddr, timestamp, info.ssid, sign)
			data.authUrl = info.authUrl
			data.extend = extend
		end
	else
		data.aid = ngx.var.aid
		data.url = ngx.var.req_url
		data.ts = ngx.time()
	end
	local args = ngx.encode_args(data)
	local redirect_url = 'http://' .. ngx.var.redirect_ip .. '/index.html?' .. args
	ngx.header['Cache-Control'] = 'no-cache, no-store, must-revalidate, pre-check=0, post-check=0'
	ngx.header['Expires'] = 'Tue, 03 Jul 2001 06:00:00 GMT'
	ngx.header['Last-Modified'] = ngx.http_time(ngx.time())
	ngx.header['Pragma'] = 'no-cache'
	return ngx.redirect(redirect_url, ngx.HTTP_MOVED_TEMPORARILY)
end

#!/bin/sh

[ x$1 = xstop ] && {
	exit 0
}

[ x$1 = xstart ] || {
	echo "usage: $0 start|stop"
	exit 0
}

nginx_server_conf_tpl="
    server {
        listen _PORT_;
        location / {
            set \$aid _AID_;
            set \$redirect_ip _SERVER_;
            set \$req_url \$scheme://\$host\$request_uri;
            rewrite_by_lua_file /tmp/userauth/lua/ngx-auth-redirect.lua;
            resolver 127.0.0.1;
            proxy_redirect off;
            proxy_pass \$req_url;
        }
    }
"
nginx_server_conf=""

wechatinfo_lua_tpl="
	{
		shopName = '_shopName_',
		appId = '_appId_',
		ssid = '_ssid_',
		shopId = '_shopId_',
		secretKey = '_secretKey_',
		authUrl = '_authUrl_'
	},
"
wechatinfo_lua="
return {
"

for rule_index in `seq 0 255`; do
	ipset -n list auth_online_list$rule_index >/dev/null 2>&1 || break
	server_ip=`uci get userauth.@rule[$rule_index].server_ip`
	test -n "$server_ip" || server_ip=10.$((0+rule_index)).0.8
	port=$((8001+rule_index))
	aid=$rule_index
	nginx_server_conf="$nginx_server_conf$(echo "$nginx_server_conf_tpl" | sed "s/_PORT_/$port/;s/_SERVER_/$server_ip/;s/_AID_/$aid/")"

	if [ x"`uci get userauth.@rule[$rule_index].wechat_disabled`" = x1 ]; then
		wechatinfo_lua="$wechatinfo_lua`echo -e '\n\tnil,'`"
	else
		shopName="`uci get userauth.@rule[$rule_index].wechat_shopName`"
		appId="`uci get userauth.@rule[$rule_index].wechat_appId`"
		ssid="`uci get userauth.@rule[$rule_index].wechat_ssid`"
		shopId="`uci get userauth.@rule[$rule_index].wechat_shopId`"
		secretKey="`uci get userauth.@rule[$rule_index].wechat_secretKey`"
		authUrl="http://$server_ip/auth-wechat-login"
		wechatinfo_lua="$wechatinfo_lua$(echo "$wechatinfo_lua_tpl" | sed "s,_shopName_,$shopName,;s,_appId_,$appId,;s,_ssid_,$ssid,;s,_shopId_,$shopId,;s,_secretKey_,$secretKey,;s,_authUrl_,$authUrl,;")"
	fi
done

wechatinfo_lua="$wechatinfo_lua`echo -e '\n}'`"

mkdir /tmp/userauth >/dev/null 2>&1 && {
	test -e /tmp/userauth/www || cp -a /usr/share/userauth/www /tmp/userauth/
}
test -d /tmp/userauth && cp -a /usr/share/userauth/lua /tmp/userauth/

mkdir -p /tmp/userauth/lua
echo "$wechatinfo_lua" >/tmp/userauth/lua/wechatinfo.lua.tmp
mv /tmp/userauth/lua/wechatinfo.lua.tmp /tmp/userauth/lua/wechatinfo.lua

cat /usr/share/userauth/nginx.conf >/tmp/nginx.conf.tmp
echo "$nginx_server_conf" >>/tmp/nginx.conf.tmp
echo "}" >>/tmp/nginx.conf.tmp
mv /tmp/nginx.conf.tmp /tmp/nginx.conf
/etc/init.d/nginx reload

exit 0

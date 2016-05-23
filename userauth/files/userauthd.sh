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
            keepalive_timeout 0;
            if_modified_since off;
            etag off;
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

for i in `seq 0 255`; do
	ipset destroy auth_online_list$i >/dev/null 2>&1 || break
	ipset destroy auth_dst_white_list$i >/dev/null 2>&1
	ipset destroy auth_ip_white_list$i >/dev/null 2>&1
	ipset destroy auth_mac_white_list$i >/dev/null 2>&1
done

ipset destroy auth_global_dst_white_list >/dev/null 2>&1
ipset create auth_global_dst_white_list hash:ip

rm -f /tmp/userauth.fw.rules
rule_index=0
for i in `seq 0 255`; do
	[ x"`uci get userauth.@rule[$i]`" = xrule ] >/dev/null 2>&1 || break
	disabled="`uci get userauth.@rule[$i].disabled`"
	[ x$disabled = x1 ] && {
		echo "info: rule [$i] disabled"
		continue
	}

	src_zone="`uci get userauth.@rule[$i].src_zone`"
	ip_range="`uci get userauth.@rule[$i].ip_range`"
	max_online_time="`uci get userauth.@rule[$i].max_online_time`"
	no_flow_offline_timeout="`uci get userauth.@rule[$i].no_flow_offline_timeout`"
	server_ip="`uci get userauth.@rule[$i].server_ip`"
	ip_white_list="`uci get userauth.@rule[$i].ip_white_list`"
	mac_white_list="`uci get userauth.@rule[$i].mac_white_list`"

	ifnames=`fw3 -q zone "$src_zone"`
	test -n "$ifnames" || {
		echo "error: rule [$i] no ifnames for src_zone[$src_zone]"
		continue
	}

	test -n "$ip_range" || {
		echo "error: rule [$i] no ip_range"
		continue
	}

	# TODO check ip_range
	test -n "$max_online_time" || max_online_time=2073600
	test -n "$no_flow_offline_timeout" || no_flow_offline_timeout=3600
	test -n "$server_ip" || server_ip=10.$((0+rule_index)).0.8

	ipset destroy auth_online_list$rule_index >/dev/null 2>&1
	ipset create auth_online_list$rule_index bitmap:ip,mac range $ip_range timeout $max_online_time counters || {
		echo "error: failed to create ipset 'auth_online_list$rule_index'"
		continue
	}
	ipset destroy auth_dst_white_list$rule_index >/dev/null 2>&1
	ipset create auth_dst_white_list$rule_index hash:net
	ipset destroy auth_ip_white_list$rule_index >/dev/null 2>&1
	ipset create auth_ip_white_list$rule_index hash:ip
	for ip in $ip_white_list; do
		ipset add auth_ip_white_list$rule_index $ip
	done
	ipset destroy auth_mac_white_list$rule_index
	ipset create auth_mac_white_list$rule_index hash:mac
	for mac in $mac_white_list; do
		ipset add auth_mac_white_list$rule_index $mac
	done

	port=$((8001+rule_index))
	aid=$rule_index
	nginx_server_conf="$nginx_server_conf$(echo "$nginx_server_conf_tpl" | sed "s/_PORT_/$port/;s/_SERVER_/$server_ip/;s/_AID_/$aid/")"

	if [ x"`uci get userauth.@rule[$i].wechat_disabled`" = x1 ]; then
		wechatinfo_lua="$wechatinfo_lua`echo -e '\n\tnil,'`"
	else
		shopName="`uci get userauth.@rule[$i].wechat_shopName`"
		appId="`uci get userauth.@rule[$i].wechat_appId`"
		ssid="`uci get userauth.@rule[$i].wechat_ssid`"
		shopId="`uci get userauth.@rule[$i].wechat_shopId`"
		secretKey="`uci get userauth.@rule[$i].wechat_secretKey`"
		authUrl="http://$server_ip/auth-wechat-login"
		wechatinfo_lua="$wechatinfo_lua$(echo "$wechatinfo_lua_tpl" | sed "s,_shopName_,$shopName,;s,_appId_,$appId,;s,_ssid_,$ssid,;s,_shopId_,$shopId,;s,_secretKey_,$secretKey,;s,_authUrl_,$authUrl,;")"
	fi

	echo "$rule_index $server_ip $port $ifnames" >>/tmp/userauth.fw.rules

	rule_index=$((rule_index+1))
done

echo -n >/tmp/auth-host-white.conf.tmp
test $rule_index -gt 0 && {
	host_white_list="`uci get userauth.@defaults[0].host_white_list`"
	for host in $host_white_list; do
		echo "ipset=/$host/auth_global_dst_white_list" >>/tmp/auth-host-white.conf.tmp
	done
}

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
/etc/init.d/nginx restart

sh /usr/share/userauth/firewall.include

rm -f /tmp/dnsmasq.d/auth-host-white.conf
test -f /tmp/auth-host-white.conf.tmp && \
	mkdir -p /tmp/dnsmasq.d && \
	cat /tmp/auth-host-white.conf.tmp | sort | uniq >/tmp/dnsmasq.d/auth-host-white.conf
/etc/init.d/dnsmasq restart

exit 0

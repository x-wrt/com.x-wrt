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
        rewrite_by_lua '
            ngx.header.cache_control = \"private, no-cache\";
            local url = require(\"socket.url\");
            local req_url = url.escape(ngx.var.scheme .. \"://\" .. ngx.var.host .. ngx.var.request_uri);
            return ngx.redirect(\"http://_SERVER_/login.lua?aid=_AID_&ts=\" .. ngx.time() .. \"&url=\" .. req_url);
        ';
    }
"
nginx_server_conf=""

for rule_index in `seq 0 255`; do
	ipset -n list auth_online_list$rule_index >/dev/null 2>&1 || break
	server_ip=`uci get userauth.@rule[$rule_index].server_ip`
	test -n "$server_ip" || server_ip=10.$((0+rule_index)).0.8
	port=$((8001+rule_index))
	aid=$rule_index
	nginx_server_conf="$nginx_server_conf$(echo "$nginx_server_conf_tpl" | sed "s/_PORT_/$port/;s/_SERVER_/$server_ip/;s/_AID_/$aid/")"
done

rm -f /tmp/nginx.conf.tmp
cat /usr/share/userauth/nginx.conf >>/tmp/nginx.conf.tmp
echo "$nginx_server_conf" >>/tmp/nginx.conf.tmp
echo "}" >>/tmp/nginx.conf.tmp
mv /tmp/nginx.conf.tmp /tmp/nginx.conf
/etc/init.d/nginx reload

mkdir /tmp/userauth >/dev/null 2>&1 && {
	test -e /tmp/userauth/www || ln -s /usr/share/userauth/www /tmp/userauth/www
	test -e /tmp/userauth/cgi-bin || ln -s /usr/share/userauth/cgi-bin /tmp/userauth/cgi-bin
}

exit 0

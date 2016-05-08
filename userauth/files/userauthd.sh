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
        rewrite ^(.*) http://10.1.0.8/_AUTH_/\$scheme://\$host\$request_uri redirect;
    }
"
nginx_server_conf=""

for i in `seq 0 255`; do
	ipset -n list auth_access_list$i >/dev/null 2>&1 || break
	port=$((8001+i))
	auth=login-$i
	nginx_server_conf="$nginx_server_conf$(echo "$nginx_server_conf_tpl" | sed "s/_PORT_/$port/;s/_AUTH_/$auth/")"
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

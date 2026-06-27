#!/bin/sh

memtotal=$(awk '/MemTotal/ {print $2}' /proc/meminfo)

#mem less than 128M
if test $memtotal -le 131072; then
	touch /tmp/natcapd.lck/cnlist
	exit 0
fi

cnlist_enable=`uci get natcapd.default.cnlist_enable 2>/dev/null || echo 0`
[ x$cnlist_enable = x1 ] || {
	touch /tmp/natcapd.lck/cnlist
	exit 0
}

gfw1_dns_magic_server=`uci get natcapd.default.gfw1_dns_magic_server 2>/dev/null || echo 8.8.8.8`

WGET=/usr/bin/wget
test -x $WGET || WGET=/bin/wget

$WGET --timeout=60 --no-check-certificate -qO /tmp/cnlist.$$.txt "https://downloads.x-wrt.com/cnlist.txt?t=`date '+%s'`" && {
	awk -F/ -v srv="$gfw1_dns_magic_server" '{print "server=/"$2"/"srv"\nipset=/"$2"/gfwlist1"}' /tmp/cnlist.$$.txt >> /tmp/accelerated-domains.cnlist.dnsmasq.$$.conf
	rm -f /tmp/cnlist.$$.txt
	mkdir -p /tmp/dnsmasq.d && \
	mv /tmp/accelerated-domains.cnlist.dnsmasq.$$.conf /tmp/dnsmasq.d/accelerated-domains.cnlist.dnsmasq.conf

	touch /tmp/natcapd.lck/cnlist
	/etc/init.d/dnsmasq restart
	exit 0
}
rm -f /tmp/cnlist.$$.txt

exit 0

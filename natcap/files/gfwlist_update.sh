#!/bin/sh

rm -f /tmp/gfwlist.txt
rm -rf /tmp/accelerated-domains.gfwlist.dnsmasq.conf
/usr/bin/wget --no-check-certificate -qO /tmp/gfwlist.txt "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"
cat /tmp/gfwlist.txt | base64 -d | grep -v ^! | grep -o '[a-zA-Z0-9][-a-zA-Z0-9]*[.][^.][-a-zA-Z0-9.]*[a-zA-Z]$' | sort | uniq | while read line; do
	echo server=/$line/8.8.8.8 >>/tmp/accelerated-domains.gfwlist.dnsmasq.conf
done

num=`cat /tmp/accelerated-domains.gfwlist.dnsmasq.conf | wc -l`
[ x$num != x0 ] && {
	mkdir -p /tmp/dnsmasq.d && mv /tmp/accelerated-domains.gfwlist.dnsmasq.conf /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf && /etc/init.d/dnsmasq restart
}

test -f /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf && exit 0

mkdir -p /tmp/dnsmasq.d && cp /usr/share/natcapd/accelerated-domains.gfwlist.dnsmasq.conf /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf && /etc/init.d/dnsmasq restart

exit 0

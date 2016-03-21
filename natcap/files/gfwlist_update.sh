#!/bin/sh

EX_DOMAIN="google.com \
		   google.com.hk \
		   google.com.tw \
		   google.com.sg \
		   google.co.jp \
		   blogspot.com \
		   blogspot.sg \
		   blogspot.hk \
		   blogspot.jp \
		   gvt1.com \
		   gvt2.com \
		   gvt3.com \
		   1e100.net \
		   blogspot.tw"

ipset create gfwlist iphash
ipset flush gfwlist

rm -f /tmp/gfwlist.txt
rm -f /tmp/accelerated-domains.gfwlist.dnsmasq.conf
/usr/bin/wget --no-check-certificate -qO /tmp/gfwlist.txt "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt" && {
	for w in `echo $EX_DOMAIN`" "`cat /tmp/gfwlist.txt | base64 -d | grep -v ^! | grep -v ^@@ | grep -o '[a-zA-Z0-9][-a-zA-Z0-9]*[.][-a-zA-Z0-9.]*[a-zA-Z]$'`; do
		echo $w
	done | sort | uniq | while read line; do
		echo server=/$line/8.8.8.8 >>/tmp/accelerated-domains.gfwlist.dnsmasq.conf
		echo ipset=/$line/gfwlist >>/tmp/accelerated-domains.gfwlist.dnsmasq.conf
	done
	rm -f /tmp/gfwlist.txt
	mkdir -p /tmp/dnsmasq.d && mv /tmp/accelerated-domains.gfwlist.dnsmasq.conf /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf && /etc/init.d/dnsmasq restart
}

test -f /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf && exit 0

mkdir -p /tmp/dnsmasq.d && cp /usr/share/natcapd/accelerated-domains.gfwlist.dnsmasq.conf /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf && /etc/init.d/dnsmasq restart

exit 0

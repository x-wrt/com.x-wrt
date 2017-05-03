#!/bin/sh

[ x`uci get natcapd.default.enable_hosts 2>/dev/null` = x1 ] || {
	[ x`readlink /etc/hosts` = "x/usr/share/natcapd/hosts" ] || ln -sf /usr/share/natcapd/hosts /etc/hosts
}

EX_DOMAIN="google.com \
		   google.com.hk \
		   google.com.tw \
		   google.com.sg \
		   google.co.jp \
		   google.ae \
		   blogspot.com \
		   blogspot.sg \
		   blogspot.hk \
		   blogspot.jp \
		   gvt1.com \
		   gvt2.com \
		   gvt3.com \
		   1e100.net \
		   blogspot.tw \
		   fastly.net \
		   amazonaws.com"

/usr/bin/wget --timeout=60 --no-check-certificate -qO /tmp/gfwlist.$$.txt "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt?t=`date '+%s'`" && {
	for w in `echo $EX_DOMAIN` `cat /tmp/gfwlist.$$.txt | base64 -d | grep -v ^! | grep -v ^@@ | grep -o '[a-zA-Z0-9][-a-zA-Z0-9]*[.][-a-zA-Z0-9.]*[a-zA-Z]$'`; do
		echo $w
	done | sort | uniq | while read line; do
		echo $line | grep -q github.com && continue
		echo server=/$line/8.8.8.8 >>/tmp/accelerated-domains.gfwlist.dnsmasq.$$.conf
		echo ipset=/$line/gfwlist >>/tmp/accelerated-domains.gfwlist.dnsmasq.$$.conf
	done
	rm -f /tmp/gfwlist.$$.txt
	mkdir -p /tmp/dnsmasq.d && mv /tmp/accelerated-domains.gfwlist.dnsmasq.$$.conf /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf && /etc/init.d/dnsmasq restart

	[ x`uci get natcapd.default.enable_hosts 2>/dev/null` = x1 ] && {
		/usr/bin/wget --timeout=60 --no-check-certificate -qO /tmp/gfwhosts.$$.txt "https://raw.githubusercontent.com/racaljk/hosts/master/hosts?t=`date '+%s'`" && {
			ipset flush gfwhosts
			mv /tmp/gfwhosts.$$.txt /tmp/natcapd.hosts
			for _ip in `cat /tmp/natcapd.hosts | grep ^[0-9].*. | grep -v localhost | awk '{print $1}' | sort | uniq`; do
				ipset add gfwhosts $_ip 2>/dev/null
			done
			[ x`readlink /etc/hosts` = "x/tmp/natcapd.hosts" ] || ln -sf /tmp/natcapd.hosts /etc/hosts
			/etc/init.d/dnsmasq restart
		}
	}
	exit 0
}

test -f /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf && exit 0

mkdir -p /tmp/dnsmasq.d && cp /usr/share/natcapd/accelerated-domains.gfwlist.dnsmasq.conf /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf && /etc/init.d/dnsmasq restart

exit 0

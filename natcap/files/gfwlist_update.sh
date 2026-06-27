#!/bin/sh

memtotal=$(awk '/MemTotal/ {print $2}' /proc/meminfo)

#mem less than 64M
if test $memtotal -le 65536; then
	touch /tmp/natcapd.lck/gfwlist
	exit 0
fi

gfwlist_enable=`uci get natcapd.default.gfwlist_enable 2>/dev/null || echo 0`
[ x$gfwlist_enable = x1 ] || {
	touch /tmp/natcapd.lck/gfwlist
	exit 0
}

access_to_cn=`uci get natcapd.default.access_to_cn 2>/dev/null || echo 0`
[ x$access_to_cn = x1 ] && {
	touch /tmp/natcapd.lck/gfwlist
	exit 0
}

cnipwhitelist_mode=`uci get natcapd.default.cnipwhitelist_mode 2>/dev/null || echo 0`
exclude_domains=
[ x$cnipwhitelist_mode = x2 ] && \
exclude_domains="google appspot \
	blogspot gvt amazon \
	facebook fbcdn twitter \
	twimg netflix nflx \
	whatsapp youtube ytimg \
	gstatic ggpht \
	pscp apple"

exclude_out()
{
	local file="$1"
	if [ -n "$exclude_domains" ]; then
		local awk_pattern
		awk_pattern=$(printf "%s\n" "$exclude_domains" | awk '{ for (i = 1; i <= NF; i++) out = out (out ? "|" : "") $i } END { print out }')
		awk -v pat="($awk_pattern)" '!($0 ~ pat)' "$file" > "$file.tmp"
		mv "$file.tmp" "$file"
	fi
}

gfw0_dns_magic_server=`uci get natcapd.default.gfw0_dns_magic_server 2>/dev/null || echo 8.8.8.8`

WGET=/usr/bin/wget
test -x $WGET || WGET=/bin/wget

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

$WGET --timeout=60 --no-check-certificate -qO /tmp/gfwlist.$$.txt "https://downloads.x-wrt.com/gfwlist.txt?t=`date '+%s'`" && {
	{
		for w in $EX_DOMAIN; do echo "$w"; done
		base64 -d /tmp/gfwlist.$$.txt | grep -v '^!' | grep -v '^@@' | grep -o '[a-zA-Z0-9][-a-zA-Z0-9]*[.][-a-zA-Z0-9.]*[a-zA-Z]$'
	} | sort -u | awk -v srv="$gfw0_dns_magic_server" '
		/github\.com/ { next }
		{ print "server=/"$1"/"srv"\nipset=/"$1"/gfwlist0" }
	' > /tmp/accelerated-domains.gfwlist.dnsmasq.$$.conf
	rm -f /tmp/gfwlist.$$.txt
	mkdir -p /tmp/dnsmasq.d && \
	mv /tmp/accelerated-domains.gfwlist.dnsmasq.$$.conf /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf && \
	exclude_out /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf

	touch /tmp/natcapd.lck/gfwlist
	/etc/init.d/dnsmasq restart
	exit 0
}
rm -f /tmp/gfwlist.$$.txt

test -f /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf && exit 0

mkdir -p /tmp/dnsmasq.d && \
sed "s,/8.8.8.8,/$gfw0_dns_magic_server,g" /usr/share/natcapd/accelerated-domains.gfwlist.dnsmasq.conf >/tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf
exclude_out /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf

/etc/init.d/dnsmasq restart

exit 0

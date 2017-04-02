#!/bin/sh

[ "x`uci get natcapd.default.pptpd`" = x1 ] && ! [ "x`uci get pptpd.pptpd.enabled`" = x1 ] && {

uci delete network.natcapd
uci set network.natcapd=interface
uci set network.natcapd.proto='none'
uci set network.natcapd.ifname='ppp+'
uci set network.natcapd.auto='1'
uci commit network

index=0
while :; do
	zone="`uci get firewall.@zone[$index].name 2>/dev/null`"
	test -n "$zone" || break
	[ "x$zone" = "xlan" ] && {
		lans="`uci get firewall.@zone[$index].network`"
		uci delete firewall.@zone[$index].network
		for w in natcapd $lans; do
			uci add_list firewall.@zone[$index].network="$w"
		done
		break
	}
	index=$((index+1))
done
uci delete firewall.natcapd_pptp_tcp
uci set firewall.natcapd_pptp_tcp=rule
uci set firewall.natcapd_pptp_tcp.target='ACCEPT'
uci set firewall.natcapd_pptp_tcp.src='wan'
uci set firewall.natcapd_pptp_tcp.proto='tcp'
uci set firewall.natcapd_pptp_tcp.dest_port='1723'
uci set firewall.natcapd_pptp_tcp.name='pptp'
uci delete firewall.natcapd_pptp_gre
uci set firewall.natcapd_pptp_gre=rule
uci set firewall.natcapd_pptp_gre.enabled='1'
uci set firewall.natcapd_pptp_gre.target='ACCEPT'
uci set firewall.natcapd_pptp_gre.src='wan'
uci set firewall.natcapd_pptp_gre.name='gre'
uci set firewall.natcapd_pptp_gre.proto='gre'
uci commit firewall

/etc/init.d/network reload
/etc/init.d/firewall reload

uci delete pptpd.pptpd
uci set pptpd.pptpd=service
uci set pptpd.pptpd.enabled='1'
uci set pptpd.pptpd.localip='10.8.8.0'
uci set pptpd.pptpd.remoteip='10.8.8.100-200'
uci set pptpd.pptpd.natcapd='1'
while uci delete pptpd.@login[0]; do :; done
echo ptpt52 153153ptpt52 | while read user pass; do
	obj=`uci add pptpd login`
	test -n "$obj" && {
		uci set pptpd.$obj.username='ptpt52'
		uci set pptpd.$obj.password='153153ptpt52'
	}
done
uci commit pptpd

/etc/init.d/pptpd restart

exit 0

}

! [ "x`uci get natcapd.default.pptpd`" = x1 ] && [ "x`uci get pptpd.pptpd.enabled`" = x1 ] && uci get pptpd.pptpd.natcapd && {

uci set pptpd.pptpd.enabled='0'
uci commit pptpd
/etc/init.d/pptpd stop

uci delete network.natcapd
uci commit network

uci delete firewall.natcapd_pptp_tcp
uci delete firewall.natcapd_pptp_gre
index=0
while :; do
	zone="`uci get firewall.@zone[$index].name 2>/dev/null`"
	test -n "$zone" || break
	[ "x$zone" = "xlan" ] && {
		lans="`uci get firewall.@zone[$index].network`"
		uci delete firewall.@zone[$index].network
		for w in natcapd $lans; do
			[ "x$w" = "xnatcapd" ] && continue
			uci add_list firewall.@zone[$index].network="$w"
		done
		break
	}
	index=$((index+1))
done
uci commit firewall

/etc/init.d/network reload
/etc/init.d/firewall reload

exit 0

}

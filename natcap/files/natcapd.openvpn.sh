#!/bin/sh

test -x /etc/init.d/openvpn || exit 0

# gen natcap-ta.key if not exist.
test -f /etc/openvpn/natcap-ta.key || {
	mkdir -p /etc/openvpn
	openvpn --genkey secret /etc/openvpn/natcap-ta.key
}

make_config()
{
	PROTO=$1
	PROTO=${PROTO-tcp}
	KEY_ID=client
	KEY_DIR=/usr/share/natcapd/openvpn
	BASE_CONFIG=/usr/share/natcapd/openvpn/client.conf
	mode="$(uci get natcapd.default.natcapovpn_tap 2>/dev/null || echo 0)"
	hname=`cat /dev/natcap_ctl  | grep default_mac_addr | grep -o '[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]' | sed 's/://g'`
	TA_KEY=${KEY_DIR}/ta.key
	test -f /etc/openvpn/natcap-ta.key && TA_KEY=/etc/openvpn/natcap-ta.key

	if [ "$mode" = "1" ]; then
		cat ${BASE_CONFIG} | sed "s/^remote .*4911$/remote $hname.dns.x-wrt.com 4911/;s/^proto tcp$/proto $PROTO/;s/dev tun/dev tap/"
		echo tun_mtu 1434
	else
		cat ${BASE_CONFIG} | sed "s/^remote .*4911$/remote $hname.dns.x-wrt.com 4911/;s/^proto tcp$/proto $PROTO/"
		echo tun_mtu 1420
	fi
	echo -e '<ca>'
	cat ${KEY_DIR}/ca.crt
	echo -e '</ca>\n<cert>'
	cat ${KEY_DIR}/${KEY_ID}.crt
	echo -e '</cert>\n<key>'
	cat ${KEY_DIR}/${KEY_ID}.key
	echo -e '</key>\n<tls-auth>'
	cat ${TA_KEY}
	echo -e '</tls-auth>'
}

[ "x$1" = "xgen_client" ] && {
	make_config tcp
	exit 0
}

[ "x$1" = "xgen_client_udp" ] && {
	make_config udp
	exit 0
}

[ "x$1" = "xgen_client6" ] && {
	make_config tcp6
	exit 0
}

[ "x$1" = "xgen_client6_udp" ] && {
	make_config udp6
	exit 0
}

[ "x`uci get natcapd.default.natcapovpn 2>/dev/null`" = x1 ] && {
	mode="$(uci get natcapd.default.natcapovpn_tap 2>/dev/null || echo 0)"
	ip6="$(uci get natcapd.default.natcapovpn_ip6 2>/dev/null || echo 0)"
	[ "x`uci get openvpn.natcapovpn_tcp4.enabled 2>/dev/null`" != x1 ] && {
		/etc/init.d/openvpn stop
		uci delete network.natcapovpn 2>/dev/null
		uci commit network

		index=0
		while :; do
			zone="`uci get firewall.@zone[$index].name 2>/dev/null`"
			test -n "$zone" || break
			[ "x$zone" = "xlan" ] && {
				lans="`uci get firewall.@zone[$index].device`"
				uci delete firewall.@zone[$index].device
				for x in natcap+ $lans; do echo $x; done | sort | uniq | while read w; do
					uci add_list firewall.@zone[$index].device="$w"
				done
				break
			}
			index=$((index+1))
		done
		for p in tcp udp; do
			uci delete firewall.natcapovpn_$p
			uci set firewall.natcapovpn_$p=rule
			uci set firewall.natcapovpn_$p.target='ACCEPT'
			uci set firewall.natcapovpn_$p.src='wan'
			uci set firewall.natcapovpn_$p.proto="$p"
			uci set firewall.natcapovpn_$p.dest_port='4911'
			uci set firewall.natcapovpn_$p.name="natcapovpn_$p"
		done
		uci commit firewall

		[ "$ip6" = "1" ] && ip6="tcp6 udp6" || ip6=""
		I=0
		for p in tcp4 udp4 $ip6; do
			uci delete openvpn.natcapovpn_$p
			uci set openvpn.natcapovpn_$p=openvpn
			uci set openvpn.natcapovpn_$p.enabled='1'
			uci set openvpn.natcapovpn_$p.port='4911'
			uci set openvpn.natcapovpn_$p.dev="natcap$p"
			if [ "$mode" = "1" ]; then
				uci set openvpn.natcapovpn_$p.dev_type='tap'
				uci set openvpn.natcapovpn_$p.tun_mtu='1434'
			else
				uci set openvpn.natcapovpn_$p.dev_type='tun'
				uci set openvpn.natcapovpn_$p.tun_mtu='1420'
			fi
			uci set openvpn.natcapovpn_$p.ca='/usr/share/natcapd/openvpn/ca.crt'
			uci set openvpn.natcapovpn_$p.cert='/usr/share/natcapd/openvpn/server.crt'
			uci set openvpn.natcapovpn_$p.key='/usr/share/natcapd/openvpn/server.key'
			uci set openvpn.natcapovpn_$p.dh='/usr/share/natcapd/openvpn/dh2048.pem'
			uci set openvpn.natcapovpn_$p.server="10.8.$((9+I)).0 255.255.255.0"
			uci set openvpn.natcapovpn_$p.keepalive='10 120'
			uci set openvpn.natcapovpn_$p.persist_key='1'
			uci set openvpn.natcapovpn_$p.persist_tun='1'
			uci set openvpn.natcapovpn_$p.user='nobody'
			uci set openvpn.natcapovpn_$p.duplicate_cn='1'
			uci set openvpn.natcapovpn_$p.status='/tmp/natcapovpn-status.log'
			uci set openvpn.natcapovpn_$p.mode='server'
			uci set openvpn.natcapovpn_$p.tls_server='1'
			uci set openvpn.natcapovpn_$p.tls_auth='/usr/share/natcapd/openvpn/ta.key 0'
			test -f /etc/openvpn/natcap-ta.key && uci set openvpn.natcapovpn_$p.tls_auth='/etc/openvpn/natcap-ta.key 0'
			uci add_list openvpn.natcapovpn_$p.push='persist-key'
			uci add_list openvpn.natcapovpn_$p.push='persist-tun'
			uci add_list openvpn.natcapovpn_$p.push='dhcp-option DNS 8.8.8.8'
			uci set openvpn.natcapovpn_$p.proto="${p}"
			uci set openvpn.natcapovpn_$p.verb='3'
			uci set openvpn.natcapovpn_$p.cipher='AES-256-GCM'
			uci set openvpn.natcapovpn_$p.auth='SHA256'
			uci set openvpn.natcapovpn_$p.topology='subnet'
			I=$((I+1))
		done
		uci commit openvpn

		/etc/init.d/openvpn start
		/etc/init.d/network reload
		/etc/init.d/firewall reload
	}
	exit 0
}

[ "x`uci get natcapd.default.natcapovpn 2>/dev/null`" != x1 ] && [ "x`uci get openvpn.natcapovpn_tcp4.enabled 2>/dev/null`" = x1 ] && {
	/etc/init.d/openvpn stop
	for p in tcp udp tcp4 udp4 tcp6 udp6; do
		uci delete openvpn.natcapovpn_$p
	done
	uci commit openvpn

	uci delete network.natcapovpn 2>/dev/null
	uci commit network

	for p in tcp udp; do
		uci delete firewall.natcapovpn_$p
	done
	index=0
	while :; do
		zone="`uci get firewall.@zone[$index].name 2>/dev/null`"
		test -n "$zone" || break
		[ "x$zone" = "xlan" ] && {
			lans="`uci get firewall.@zone[$index].device`"
			uci delete firewall.@zone[$index].device
			for w in $lans; do
				[ "x$w" = "xnatcap+" ] && continue
				uci add_list firewall.@zone[$index].device="$w"
			done
			break
		}
		index=$((index+1))
	done
	uci commit firewall

	/etc/init.d/openvpn start
	/etc/init.d/network reload
	/etc/init.d/firewall reload
	exit 0
}

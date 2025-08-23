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
	hname=$(awk -F= '/default_mac_addr/ { gsub(":", "", $2); print $2 }' /dev/natcap_ctl)

	TA_KEY=${KEY_DIR}/ta.key
	test -f /etc/openvpn/natcap-ta.key && TA_KEY=/etc/openvpn/natcap-ta.key

	if [ "$mode" = "1" ]; then
		cat ${BASE_CONFIG} | sed "s/^remote .*4911$/remote $hname.dns.x-wrt.com 4911/;s/^proto tcp$/proto $PROTO/;s/dev tun/dev tap/"
		echo tun-mtu 1404
	else
		cat ${BASE_CONFIG} | sed "s/^remote .*4911$/remote $hname.dns.x-wrt.com 4911/;s/^proto tcp$/proto $PROTO/"
		echo tun-mtu 1420
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
	make_config tcp-client
	exit 0
}

[ "x$1" = "xgen_client_udp" ] && {
	make_config udp
	exit 0
}

[ "x$1" = "xgen_client6" ] && {
	make_config tcp6-client
	exit 0
}

[ "x$1" = "xgen_client6_udp" ] && {
	make_config udp6
	exit 0
}

[ "x`uci get natcapd.default.natcapovpn 2>/dev/null`" = x1 ] && {
	mode="$(uci get natcapd.default.natcapovpn_tap 2>/dev/null || echo 0)"
	ip6="$(uci get natcapd.default.natcapovpn_ip6 2>/dev/null || echo 0)"
	oldhash=$(uci get openvpn.natcapovpn_tcp.oldhash)
	newhash="1${mode}${ip6}1"
	[ "$oldhash" != "$newhash" ] && {
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
		I=0
		for p in tcp udp; do
			uci delete firewall.natcapovpn_$p
			uci set firewall.natcapovpn_$p=rule
			uci set firewall.natcapovpn_$p.target='ACCEPT'
			uci set firewall.natcapovpn_$p.src='wan'
			uci set firewall.natcapovpn_$p.proto="$p"
			uci set firewall.natcapovpn_$p.dest_port='4911'
			uci set firewall.natcapovpn_$p.name="natcapovpn_$p"
			uci set firewall.natcapovpn_masq_$p=nat
			uci set firewall.natcapovpn_masq_$p.name="natcapovpn_masq_$p"
			uci set firewall.natcapovpn_masq_$p.proto='all'
			uci set firewall.natcapovpn_masq_$p.src='lan'
			uci set firewall.natcapovpn_masq_$p.src_ip="10.8.$((9+I)).0/24"
			uci set firewall.natcapovpn_masq_$p.target='MASQUERADE'
			I=$((I+1))
		done
		uci commit firewall

		I=0
		for p in tcp udp; do
			uci delete openvpn.natcapovpn_$p
			uci set openvpn.natcapovpn_$p=openvpn
			uci set openvpn.natcapovpn_$p.oldhash="$newhash"
			uci set openvpn.natcapovpn_$p.enabled='1'
			uci set openvpn.natcapovpn_$p.port='4911'
			uci set openvpn.natcapovpn_$p.dev="natcap$p"
			if [ "$mode" = "1" ]; then
				uci set openvpn.natcapovpn_$p.dev_type='tap'
				uci set openvpn.natcapovpn_$p.tun_mtu='1404'
			else
				uci set openvpn.natcapovpn_$p.dev_type='tun'
				uci set openvpn.natcapovpn_$p.tun_mtu='1420'
			fi
			uci set openvpn.natcapovpn_$p.ca='/usr/share/natcapd/openvpn/ca.crt'
			uci set openvpn.natcapovpn_$p.cert='/usr/share/natcapd/openvpn/server.crt'
			uci set openvpn.natcapovpn_$p.key='/usr/share/natcapd/openvpn/server.key'
			uci set openvpn.natcapovpn_$p.dh='/usr/share/natcapd/openvpn/dh2048.pem'
			uci set openvpn.natcapovpn_$p.server="10.8.$((9+I)).0 255.255.255.0"
			uci set openvpn.natcapovpn_$p.keepalive='10 60'
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
			if [ "$p" = "tcp" ]; then
				if [ "$ip6" = "1" ]; then
					#ipv4 ipv6 dual support
					uci set openvpn.natcapovpn_$p.proto="${p}6-server"
				else
					uci set openvpn.natcapovpn_$p.proto="${p}4-server"
				fi
			else
				if [ "$ip6" = "1" ]; then
					#ipv4 ipv6 dual support
					uci set openvpn.natcapovpn_$p.proto="${p}6"
				else
					uci set openvpn.natcapovpn_$p.proto="${p}4"
				fi
				uci set openvpn.natcapovpn_$p.multihome='1'
			fi
			uci set openvpn.natcapovpn_$p.verb='3'
			uci set openvpn.natcapovpn_$p.cipher='AES-256-GCM'
			uci set openvpn.natcapovpn_$p.auth='SHA256'
			uci set openvpn.natcapovpn_$p.topology='subnet'
			uci set openvpn.natcapovpn_$p.client_to_client='1'
			I=$((I+1))
		done
		uci commit openvpn

		/etc/init.d/openvpn start
		/etc/init.d/network reload
		/etc/init.d/firewall reload
	}
	exit 0
}

[ "x`uci get natcapd.default.natcapovpn 2>/dev/null`" != x1 ] && [ "x`uci get openvpn.natcapovpn_tcp.enabled 2>/dev/null`" = x1 ] && {
	/etc/init.d/openvpn stop
	for p in tcp udp tcp4 udp4 tcp6 udp6; do
		uci delete openvpn.natcapovpn_$p
	done
	uci commit openvpn

	uci delete network.natcapovpn 2>/dev/null
	uci commit network

	for p in tcp udp; do
		uci delete firewall.natcapovpn_$p
		uci delete firewall.natcapovpn_masq_$p
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

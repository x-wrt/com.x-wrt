#!/bin/sh

gen_client() {
	rm -rf /tmp/natcap-client
	mkdir /tmp/natcap-client
	cp /usr/share/natcapd/openvpn/natcap-client.key /tmp/natcap-client/
	cp /usr/share/natcapd/openvpn/natcap-client.crt /tmp/natcap-client/
	cp /usr/share/natcapd/openvpn/ca.crt /tmp/natcap-client/natcap-client-ca.crt
	cp /usr/share/natcapd/openvpn/ta.key /tmp/natcap-client/natcap-client-ta.key
	hname=`cat /dev/natcap_ctl  | grep default_mac_addr | grep -o '[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]' | sed 's/://g' | tr A-F a-f`
	cat /usr/share/natcapd/openvpn/natcap-client.conf | sed "s/^remote .*4911$/remote $hname.dns.ptpt52.com 4911/" >/tmp/natcap-client/natcap-client.conf
	cd /tmp && {
		tar czf /tmp/natcap-client.tgz natcap-client
		rm -rf natcap-client
		cd - >/dev/null 2>&1
	}
}

[ "x$1" = "xgen_client" ] && {
	gen_client
	exit 0
}

[ "x`uci get natcapd.default.natcapovpn`" = x1 ] && {
	! [ "x`uci get openvpn.natcapovpn.enabled`" = x1 ] && {
		uci delete network.natcapovpn
		uci set network.natcapovpn=interface
		uci set network.natcapovpn.proto='none'
		uci set network.natcapovpn.ifname='natcap'
		uci set network.natcapovpn.auto='1'
		uci commit network

		index=0
		while :; do
			zone="`uci get firewall.@zone[$index].name 2>/dev/null`"
			test -n "$zone" || break
			[ "x$zone" = "xlan" ] && {
				lans="`uci get firewall.@zone[$index].network`"
				uci delete firewall.@zone[$index].network
				for w in natcapovpn $lans; do
					uci add_list firewall.@zone[$index].network="$w"
				done
				break
			}
			index=$((index+1))
		done
		uci delete firewall.natcapovpn_tcp
		uci set firewall.natcapovpn_tcp=rule
		uci set firewall.natcapovpn_tcp.target='ACCEPT'
		uci set firewall.natcapovpn_tcp.src='wan'
		uci set firewall.natcapovpn_tcp.proto='tcp'
		uci set firewall.natcapovpn_tcp.dest_port='4911'
		uci set firewall.natcapovpn_tcp.name='natcapovpn'
		uci commit firewall

		/etc/init.d/network reload
		/etc/init.d/firewall reload

		uci delete openvpn.natcapovpn
		uci set openvpn.natcapovpn=openvpn
		uci set openvpn.natcapovpn.enabled='1'
		uci set openvpn.natcapovpn.port='4911'
		uci set openvpn.natcapovpn.dev='natcap'
		uci set openvpn.natcapovpn.dev_type='tun'
		uci set openvpn.natcapovpn.ca='/usr/share/natcapd/openvpn/ca.crt'
		uci set openvpn.natcapovpn.cert='/usr/share/natcapd/openvpn/server.crt'
		uci set openvpn.natcapovpn.key='/usr/share/natcapd/openvpn/server.key'
		uci set openvpn.natcapovpn.dh='/usr/share/natcapd/openvpn/dh2048.pem'
		uci set openvpn.natcapovpn.server='10.8.9.0 255.255.255.0'
		uci set openvpn.natcapovpn.keepalive='10 120'
		uci set openvpn.natcapovpn.compress='lzo'
		uci set openvpn.natcapovpn.persist_key='1'
		uci set openvpn.natcapovpn.persist_tun='1'
		uci set openvpn.natcapovpn.user='nobody'
		uci set openvpn.natcapovpn.ifconfig_pool_persist='/tmp/ipp-natcapovpn.txt'
		uci set openvpn.natcapovpn.status='/tmp/natcapovpn-status.log'
		uci set openvpn.natcapovpn.verb='3'
		uci set openvpn.natcapovpn.mode='server'
		uci set openvpn.natcapovpn.tls_server='1'
		uci set openvpn.natcapovpn.tls_auth='/usr/share/natcapd/openvpn/ta.key 0'
		uci set openvpn.natcapovpn.route_gateway='dhcp'
		uci set openvpn.natcapovpn.client_to_client='1'
		uci add_list openvpn.natcapovpn.push='persist-key'
		uci add_list openvpn.natcapovpn.push='persist-tun'
		uci add_list openvpn.natcapovpn.push='redirect-gateway def1'
		uci add_list openvpn.natcapovpn.push='dhcp-option DNS 8.8.8.8'
		uci set openvpn.natcapovpn.duplicate_cn='1'
		uci set openvpn.natcapovpn.proto='tcp4'
		uci set openvpn.natcapovpn.comp_lzo='yes'
		uci commit openvpn
	}

	/etc/init.d/openvpn restart
	exit 0
}

! [ "x`uci get natcapd.default.natcapovpn`" = x1 ] && [ "x`uci get openvpn.natcapovpn.enabled`" = x1 ] && {
	/etc/init.d/openvpn stop
	uci delete openvpn.natcapovpn
	uci commit openvpn
	/etc/init.d/openvpn start

	uci delete network.natcapovpn
	uci commit network

	uci delete firewall.natcapovpn_tcp
	index=0
	while :; do
		zone="`uci get firewall.@zone[$index].name 2>/dev/null`"
		test -n "$zone" || break
		[ "x$zone" = "xlan" ] && {
			lans="`uci get firewall.@zone[$index].network`"
			uci delete firewall.@zone[$index].network
			for w in natcapovpn $lans; do
				[ "x$w" = "xnatcapovpn" ] && continue
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

#!/bin/sh

DEV=/dev/natcap_ctl

#delfwindex MINIUPNPD 1
#cmd     iaddr   iport eport
#addrule 1.2.3.4 1234  1234
#delrule 1.2.3.4 1234  1234

cmd=$1

get_fw_cone_unused_ports() {
	local idx=0
	while uci get firewall.@rule[$idx] >>/dev/null 2>&1; do
		dp=$(uci get firewall.@rule[$idx].dest_port 2>/dev/null)
		fm=$(uci get firewall.@rule[$idx].family 2>/dev/null)
		po=$(uci get firewall.@rule[$idx].proto 2>/dev/null)
		if ( [ "x$po" = "x" ] || echo $po | grep -q udp ) && ( [ "x$fm" = "x" ] || echo $fm | grep -q ipv4 ); then
			echo $dp
		fi
		idx=$((idx+1))
	done
	idx=0
	while uci get firewall.@redirect[$idx].src_dport >>/dev/null 2>&1; do
		dp=$(uci get firewall.@redirect[$idx].src_dport 2>/dev/null)
		po=$(uci get firewall.@redirect[$idx].proto 2>/dev/null)
		if ( [ "x$po" = "x" ] || echo $po | grep -q udp ); then
			echo $dp
		fi
		idx=$((idx+1))
	done
}

init_cone_nat_unused()
{
	ipset destroy cone_nat_unused_dst >/dev/null 2>&1
	ipset create cone_nat_unused_dst hash:ip,port hashsize 64 maxelem 65536 >/dev/null 2>&1
	# load dst from uci natcapd.default.cone_nat_unused_dst: ex 1.2.3.4,udp:1234
	for dst in `uci get natcapd.default.cone_nat_unused_dst 2>/dev/null`; do
		ipset add cone_nat_unused_dst $dst >/dev/null 2>&1
	done

	ipset destroy cone_nat_unused_port >/dev/null 2>&1
	ipset create cone_nat_unused_port bitmap:port range 0-65535 >/dev/null 2>&1
	# load port from uci natcapd.default.cone_nat_unused_port
	for port in `uci get natcapd.default.cone_nat_unused_port 2>/dev/null`; do
		ipset add cone_nat_unused_port $port >/dev/null 2>&1
	done
	# load ports from /tmp/run/miniupnpd.leases
	awk -F: '
		function valid_port(port) {
			return port ~ /^[0-9]+$/ && port > 0 && port <= 65535
		}
		function valid_addr(addr, octets, count, i) {
			count = split(addr, octets, /\./)
			if (count != 4) return 0
			for (i = 1; i <= count; i++)
				if (octets[i] !~ /^[0-9]+$/ || octets[i] > 255) return 0
			return 1
		}
		$1 == "UDP" {
			# Legacy: PROTO:eport:iaddr:iport:timestamp:desc
			# RemoteHost: PROTO:eport:rhost:iaddr:iport:timestamp:desc
			if (valid_addr($3) && valid_port($4)) {
				iaddr = $3
				iport = $4
			} else {
				iaddr = $4
				iport = $5
			}
			if (valid_port($2) && valid_addr(iaddr) && valid_port(iport))
				print $2, iaddr, iport
		}
	' /tmp/run/miniupnpd.leases 2>/dev/null | while read -r eport iaddr iport; do
		ipset add cone_nat_unused_port $eport >/dev/null 2>&1
		ipset add cone_nat_unused_dst $iaddr,udp:$iport >/dev/null 2>&1
		lock /var/run/natcapd.lock
		for eaddr in $(ipset list cone_wan_ip | grep ^[1-9]); do
			echo cone_nat_drop=$iaddr:$iport-$eaddr:$eport >$DEV
		done
		lock -u /var/run/natcapd.lock
	done

	get_fw_cone_unused_ports | while read eport; do
		ipset add cone_nat_unused_port $eport >/dev/null 2>&1
	done
}

case $cmd in
	addrule)
	iaddr=$2
	iport=$3
	eport=$4
	# Do not submit an incomplete mapping to the kernel control interface.
	test -n "$iaddr" && test -n "$iport" && test -n "$eport" || exit 1
	ipset add cone_nat_unused_port $eport >/dev/null 2>&1
	ipset add cone_nat_unused_dst $iaddr,udp:$iport >/dev/null 2>&1
	lock /var/run/natcapd.lock
	for eaddr in $(ipset list cone_wan_ip | grep ^[1-9]); do
		echo cone_nat_drop=$iaddr:$iport-$eaddr:$eport >$DEV
	done
	lock -u /var/run/natcapd.lock
	;;

	delrule)
	iaddr=$2
	iport=$3
	eport=$4
	test -n "$eport" && \
	ipset del cone_nat_unused_port $eport >/dev/null 2>&1

	test -n "$iaddr" && test -n "$iport" && \
	ipset del cone_nat_unused_dst $iaddr,udp:$iport >/dev/null 2>&1
	;;

	init)
	init_cone_nat_unused
	;;
esac

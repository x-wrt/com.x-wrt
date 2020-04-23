#!/bin/sh

#delfwindex MINIUPNPD 1
#cmd     iaddr   iport eport
#addrule 1.2.3.4 1234  1234
#delrule 1.2.3.4 1234  1234

cmd=$1

init_cone_nat_unused_port()
{
	ipset destroy cone_nat_unused_dst >/dev/null 2>&1
	ipset create cone_nat_unused_dst hash:ip,port hashsize 64 maxelem 65536 >/dev/null 2>&1
	# load dst from uci natcapd.default.cone_nat_unused_dst: ex 1.2.3.4,udp:1234
	for dst in `uci get natcapd.default.cone_nat_unused_dst 2>/null`; do
		ipset add cone_nat_unused_dst $dst >/dev/null 2>&1
	done

	ipset destroy cone_nat_unused_port >/dev/null 2>&1
	ipset create cone_nat_unused_port bitmap:port range 0-65535 >/dev/null 2>&1
	# load port from uci natcapd.default.cone_nat_unused_port
	for port in `uci get natcapd.default.cone_nat_unused_port 2>/null`; do
		ipset add cone_nat_unused_port $port >/dev/null 2>&1
	done
	# load ports from /tmp/run/miniupnpd.leases
	cat /tmp/run/miniupnpd.leases | grep ^UDP | cat /tmp/run/miniupnpd.leases | cut -d: -f2,3,4 | sed 's/:/ /g' | while read eport iaddr iport; do
		ipset add cone_nat_unused_port $eport >/dev/null 2>&1
		ipset add cone_nat_unused_dst $iaddr,udp:$iport >/dev/null 2>&1
	done
}

case $cmd in
	delfwindex)
	chain=$2
	index=$3
	port=`iptables -t nat -L $chain $index | grep -o "udp dpt:[0-9]*" | cut -d: -f2 | head -n1`
	test -n "$port" && \
	ipset del cone_nat_unused_port $port >/dev/null 2>&1
	;;

	addrule)
	iaddr=$2
	iport=$3
	eport=$4
	test -n "$eport" && \
	ipset add cone_nat_unused_port $eport >/dev/null 2>&1
	test -n "$iaddr" && test -n "$iport" && \
	ipset add cone_nat_unused_dst $iaddr,udp:$iport >/dev/null 2>&1
	;;

	delrule)
	iaddr=$2
	iport=$3
	eport=$4
	test -n "$port" && \
	ipset del cone_nat_unused_port $port >/dev/null 2>&1
	if iptables -t nat -L MINIUPNPD  | grep -q "^DNAT.*to:$iaddr:$iport$"; then
		:
	else
		test -n "$iaddr" && test -n "$iport" && \
		ipset del cone_nat_unused_dst $iaddr,udp:$iport >/dev/null 2>&1
	fi
	;;

	init)
	init_cone_nat_unused_port
	;;
esac

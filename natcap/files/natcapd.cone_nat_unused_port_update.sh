#!/bin/sh

#delfwindex MINIUPNPD 1
#addport 1234
#delport 1234

cmd=$1

init_cone_nat_unused_port()
{
	ipset destroy cone_nat_unused_port >/dev/null 2>&1
	ipset create cone_nat_unused_port bitmap:port range 0-65535 >/dev/null 2>&1
	# load ports from uci natcapd.default.cone_nat_unused_port
	for port in `uci get natcapd.default.cone_nat_unused_port 2>/null`; do
		ipset add cone_nat_unused_port $port >/dev/null 2>&1
	done
	# load ports from /tmp/run/miniupnpd.leases
	cat /tmp/run/miniupnpd.leases | grep ^UDP | cut -d: -f2 | while read port; do
		ipset add cone_nat_unused_port $port >/dev/null 2>&1
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

	addport)
	port=$2
	test -n "$port" && \
	ipset add cone_nat_unused_port $port >/dev/null 2>&1
	;;

	delport)
	port=$2
	test -n "$port" && \
	ipset del cone_nat_unused_port $port >/dev/null 2>&1
	;;

	init)
	init_cone_nat_unused_port
	;;
esac

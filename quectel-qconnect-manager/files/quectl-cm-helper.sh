#!/bin/sh

device=$1
ifname=$2
mtu=$3

test -n "$mtu" && test -n "$ifname" && {
	ifconfig "${ifname}_1" &>/dev/null && \
	/sbin/ip link set dev "${ifname}_1" mtu $mtu || \
	/sbin/ip link set dev "${ifname}" mtu $mtu
}

exit 0

#!/bin/sh
# Copyright (C) 2009 OpenWrt.org

switch_is_diff()
{
	local ret=0
	local name=$1
	local i=0
	mkdir -p /tmp/switch
	echo -n >/tmp/switch/$name.new
	i=0
	while [ x`uci get network.@switch[$i].name 2>/dev/null` = x$name ]; do
		uci show network.@switch[$i] >>/tmp/switch/$name.new
		i=$(($i+1))
	done
	i=0
	while [ x`uci get network.@switch_vlan[$i].device 2>/dev/null` = x$name ]; do
		uci show network.@switch_vlan[$i] >>/tmp/switch/$name.new
		i=$(($i+1))
	done
	i=0
	while [ x`uci get network.@switch_port[$i].device 2>/dev/null` = x$name ]; do
		uci show network.@switch_port[$i] >>/tmp/switch/$name.new
		i=$(($i+1))
	done
	test -f /tmp/switch/$name.old && {
		[ x`md5sum /tmp/switch/$name.old | head -c32` = x`md5sum /tmp/switch/$name.new | head -c32` ] && ret=1
	}

	mv /tmp/switch/$name.new /tmp/switch/$name.old
	return $ret
}


setup_switch_dev() {
	local name
	config_get name "$1" name
	name="${name:-$1}"
	[ -d "/sys/class/net/$name" ] && ip link set dev "$name" up
	switch_is_diff "$name" || return
	swconfig dev "$name" load network
}

setup_switch() {
	config_load network
	config_foreach setup_switch_dev switch
}

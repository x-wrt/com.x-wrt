#!/bin/sh

CFGS="`cat feeds/ptpt52/rom/lede/cfg.list`"

test -n "$CONFIG_VERSION_NUMBER" || CONFIG_VERSION_NUMBER="3.0.0_build`date +%Y%m%d%H%M`"

find target/linux/ feeds/luci/ feeds/packages/ package/ -name Makefile -exec touch {} \;

for cfg in $CFGS; do
	cp feeds/ptpt52/rom/lede/$cfg .config
	sed -i "s/CONFIG_VERSION_NUMBER=\".*\"/CONFIG_VERSION_NUMBER=\"$CONFIG_VERSION_NUMBER\"/" ./.config
	make menuconfig && make kernel_menuconfig && {
		sh feeds/ptpt52/rom/lede/makemenuconfig_parse.sh
		cp .config feeds/ptpt52/rom/lede/$cfg
	}
done

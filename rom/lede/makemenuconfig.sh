#!/bin/sh

CFGS="`cat feeds/x/rom/lede/cfg.list`"

test -n "$CONFIG_VERSION_NUMBER" || CONFIG_VERSION_NUMBER="5.0_b`date +%Y%m%d%H%M`"

CONFIG_VERSION_DIST="X-WRT"
CONFIG_VERSION_CODE="Disco"
CONFIG_VERSION_MANUFACTURER_URL="https://x-wrt.com/rom/"

find target/linux/ feeds/luci/ feeds/packages/ package/ -name Makefile -exec touch {} \;

for cfg in $CFGS; do
	echo loading... $cfg
	cp feeds/x/rom/lede/$cfg .config
	sed -i "s/CONFIG_VERSION_NUMBER=\".*\"/CONFIG_VERSION_NUMBER=\"$CONFIG_VERSION_NUMBER\"/" ./.config
	sed -i "s/CONFIG_VERSION_DIST=\".*\"/CONFIG_VERSION_DIST=\"$CONFIG_VERSION_DIST\"/" ./.config
	sed -i "s/CONFIG_VERSION_CODE=\".*\"/CONFIG_VERSION_CODE=\"$CONFIG_VERSION_CODE\"/" ./.config
	sed -i "s%CONFIG_VERSION_MANUFACTURER_URL=\".*\"%CONFIG_VERSION_MANUFACTURER_URL=\"$CONFIG_VERSION_MANUFACTURER_URL\"%" ./.config
	test -n "$1" || exit 255
	$* || exit 255
	test -n "$SIMPLE" || sh feeds/x/rom/lede/makemenuconfig_parse.sh
	cp .config feeds/x/rom/lede/$cfg
	sleep 1
done

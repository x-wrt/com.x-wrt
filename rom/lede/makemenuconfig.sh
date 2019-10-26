#!/bin/sh

CONFDIR=`dirname $0`
test -n "$CFGS" || CFGS="`cat $CONFDIR/cfg.list`"
. $CONFDIR/buildinfo.conf
test -n "$CONFIG_VERSION_NUMBER" || CONFIG_VERSION_NUMBER="${CONFIG_VERSION_VER}_b`date +%Y%m%d%H%M`"

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

#!/bin/bash

test -n "$CFGS" || CFGS="`cat feeds/ptpt52/rom/lede/cfg.list`"

test -n "$IDXS" || IDXS="0"

test -n "$CONFIG_VERSION_NUMBER" || CONFIG_VERSION_NUMBER="4.0_b`date +%Y%m%d%H%M`"

set -x
test -f .build_ptpt52/env && source .build_ptpt52/env
set +x

echo build starting
echo "CFGS=[$CFGS]"
echo "IDXS=[$IDXS]"
echo "CONFIG_VERSION_NUMBER=$CONFIG_VERSION_NUMBER"
mkdir -p .build_ptpt52
echo "CONFIG_VERSION_NUMBER=\"$CONFIG_VERSION_NUMBER\"" >.build_ptpt52/env
sleep 5

find feeds/luci/ -type f | grep -v .git\* | while read file; do
	sed -i 's/192\.168\.1\./192\.168\.15\./g' "$file" && echo modifying $file
done

CONFIG_VERSION_DIST="NATCAP"
CONFIG_VERSION_CODE="Bionic"
CONFIG_VERSION_MANUFACTURER_URL="https://router-sh.ptpt52.com/"
for i in $IDXS; do
	[ $i = 1 ] && {
		CONFIG_VERSION_DIST="BICT"
		CONFIG_VERSION_CODE="router"
		CONFIG_VERSION_MANUFACTURER_URL="http://bict.cn/"
	}

	touch ./package/base-files/Makefile

	for cfg in $CFGS; do
		test -f .build_ptpt52/$cfg && continue
		set -x
		cp feeds/ptpt52/rom/lede/$cfg .config
		sed -i "s/CONFIG_VERSION_NUMBER=\".*\"/CONFIG_VERSION_NUMBER=\"$CONFIG_VERSION_NUMBER\"/" ./.config
		sed -i "s/CONFIG_VERSION_DIST=\".*\"/CONFIG_VERSION_DIST=\"$CONFIG_VERSION_DIST\"/" ./.config
		sed -i "s/CONFIG_VERSION_CODE=\".*\"/CONFIG_VERSION_CODE=\"$CONFIG_VERSION_CODE\"/" ./.config
		sed -i "s%CONFIG_VERSION_MANUFACTURER_URL=\".*\"%CONFIG_VERSION_MANUFACTURER_URL=\"$CONFIG_VERSION_MANUFACTURER_URL\"%" ./.config
		touch ./package/base-files/files/etc/openwrt_release
		set +x
		test -n "$1" || exit 255
		$* || exit 255
		touch .build_ptpt52/$cfg
	done
done

build_in=$(cd feeds/ptpt52/rom/lede/ && cat $CFGS | grep TARGET_DEVICE_.*=y | sed 's/CONFIG_//;s/=y//' | wc -l)
build_out=$(find bin/targets/ | grep -- '\(-squashfs\|-factory\|-sysupgrade\)' | grep -v factory | grep natcap | grep -v root | grep -v kernel | sort | wc -l)
echo in=$build_in out=$build_out
echo

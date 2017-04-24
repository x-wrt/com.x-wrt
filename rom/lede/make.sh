#!/bin/sh

#arg1=CFGS
#arg2=idxs
CFGS=$1
IDXS=$2

test -n "$CFGS" || CFGS="config.apm821xx_nand config.kirkwood-generic config.ipq806x-generic config.bcm53xx-generic config.ar71xx-generic config.ar71xx-nand config.mvebu-generic config.ramips-mt7620 config.ramips-mt7621"

test -n "$IDXS" || IDXS="0"

echo build starting
echo "CFGS=[$CFGS]"
echo "IDXS=[$IDXS]"
sleep 1

CONFIG_VERSION_NUMBER="3.0.0_build`date +%Y%m%d%H%M`"

find feeds/luci/ -type f | grep -v .git\* | while read file; do
	sed -i 's/192\.168\.1\./192\.168\.15\./g' "$file" && echo modifying $file
done

CONFIG_VERSION_DIST="PTPT52"
CONFIG_VERSION_NICK="fuckgfw"
CONFIG_VERSION_MANUFACTURER_URL="http://router.ptpt52.com/"
for i in $IDXS; do
	[ $i = 1 ] && {
		CONFIG_VERSION_DIST="BICT"
		CONFIG_VERSION_NICK="router"
		CONFIG_VERSION_MANUFACTURER_URL="http://bict.cn/"
	}

	touch ./package/base-files/Makefile

	for cfg in $CFGS; do
	set -x
		cp feeds/ptpt52/rom/lede/$cfg .config
		sed -i "s/CONFIG_VERSION_NUMBER=\".*\"/CONFIG_VERSION_NUMBER=\"$CONFIG_VERSION_NUMBER\"/" ./.config
		sed -i "s/CONFIG_VERSION_DIST=\".*\"/CONFIG_VERSION_DIST=\"$CONFIG_VERSION_DIST\"/" ./.config
		sed -i "s/CONFIG_VERSION_NICK=\".*\"/CONFIG_VERSION_NICK=\"$CONFIG_VERSION_NICK\"/" ./.config
		sed -i "s%CONFIG_VERSION_MANUFACTURER_URL=\".*\"%CONFIG_VERSION_MANUFACTURER_URL=\"$CONFIG_VERSION_MANUFACTURER_URL\"%" ./.config
		touch ./package/base-files/files/etc/openwrt_release
		set +x
		make clean && make -j8 || exit 255
	done
done

build_in=$(cd feeds/ptpt52/rom/lede/ && cat $CFGS | grep TARGET_DEVICE_.*=y | sed 's/CONFIG_//;s/=y//' | wc -l)
build_out=$(find bin/targets/ | grep -- '\(-squashfs\|-factory\|-sysupgrade\)' | grep -v factory | grep ptpt52 | grep -v root | grep -v kernel | sort | wc -l)
echo in=$build_in out=$build_out
echo

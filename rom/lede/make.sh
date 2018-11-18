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

	last_arch=
	for cfg in $CFGS; do
		test -f .build_ptpt52/$cfg && continue
		set -x
		cp feeds/ptpt52/rom/lede/$cfg .config
		sed -i "s/CONFIG_VERSION_NUMBER=\".*\"/CONFIG_VERSION_NUMBER=\"$CONFIG_VERSION_NUMBER\"/" ./.config
		sed -i "s/CONFIG_VERSION_DIST=\".*\"/CONFIG_VERSION_DIST=\"$CONFIG_VERSION_DIST\"/" ./.config
		sed -i "s/CONFIG_VERSION_CODE=\".*\"/CONFIG_VERSION_CODE=\"$CONFIG_VERSION_CODE\"/" ./.config
		sed -i "s%CONFIG_VERSION_MANUFACTURER_URL=\".*\"%CONFIG_VERSION_MANUFACTURER_URL=\"$CONFIG_VERSION_MANUFACTURER_URL\"%" ./.config
		sleep 2
		touch ./package/base-files/files/etc/openwrt_release
		touch ./feeds/packages/libs/libgpg-error/Makefile
		new_arch=$(cat .config | grep CONFIG_TARGET_ARCH_PACKAGES | cut -d\" -f2)
		new_subarch=$(cat .config | grep -o  "CONFIG_TARGET_[a-z0-9]*_[a-z0-9]*=y" | sed 's/=y//' | cut -d_ -f3,4)
		test -n "$last_arch" || last_arch=$new_arch
		test -n "$last_subarch" || last_subarch=$new_subarch
		set +x
		[ "x$TMPFS" = x1 ] && {
			if [ "$last_arch" != "$new_arch" ]; then
				rm -rf build_dir/target-* build_dir/toolchain-*
				last_arch=$new_arch
				last_subarch=$new_subarch
			elif [ "$last_subarch" != "$new_subarch" ]; then
				rm -rf build_dir/target-*/linux-$last_subarch
				last_subarch=$new_subarch
			fi
		}
		test -n "$1" || exit 255
		$* || {
			touch ./feeds/packages/libs/libgpg-error/Makefile
			$* || exit 255
		}
		touch .build_ptpt52/$cfg
	done
done

build_in=$(cd feeds/ptpt52/rom/lede/ && cat $CFGS | grep TARGET_DEVICE_.*=y | sed 's/CONFIG_//;s/=y//' | wc -l)
build_out=$(find bin/targets/ | grep -- '\(-squashfs\|-factory\|-sysupgrade\)' | grep -v factory | grep natcap | grep -v root | grep -v kernel | sort | wc -l)
echo in=$build_in out=$build_out
echo

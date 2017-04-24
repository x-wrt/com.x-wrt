#!/bin/sh

#arg1=CFGS
#arg2=idxs
CFGS=$1
IDXS=$2

test -n "$CFGS" || CFGS="`cat feeds/ptpt52/rom/lede/cfg.list`"

test -n "$IDXS" || IDXS="0"

bins="`find bin/targets/ | grep -- '\(-squashfs\|-factory\|-sysupgrade\)' | grep ptpt52 | grep -v root | grep -v kernel | while read line; do basename $line; done`"

targets=$(cd feeds/ptpt52/rom/lede/ && cat $CFGS | grep TARGET_DEVICE_.*=y | sed 's/CONFIG_//;s/=y//')

echo -n >map.list
for t in $targets; do
	echo $t | sed 's/_DEVICE_/ /g' | sed 's/_/ /' | while read a arch c name; do
		test -n $arch || continue
		test -n "$name" || name=$c
		text=`cat target/linux/$arch/image/*.mk target/linux/$arch/image/Makefile 2>/dev/null | grep "define .*Device\/$name" -A20 | while read line; do [ "x$line" = "xendef" ] && break; echo $line; done`
		dis=`echo "$text" | grep "DEVICE_TITLE :=" | head -n1 | sed 's/DEVICE_TITLE :=//'`
		test -n "$dis" || {
			dis=`echo "$text" | grep '$(call Device' | head -n1 | cut -d, -f2 | sed 's/)$//g'`
		}
		bin=`echo "$bins" | grep -i "$name-"`
		test -n "$bin" || {
			bin=$(echo "$bins" | grep -i "`echo $name | head -c5`" | grep $arch)
		}
		echo "`echo $dis`:"
		for i in $bin; do echo $i; done
		echo
		echo "`echo $dis`:"$bin >>map.list
	done
done | while read line; do echo $line; done

#!/bin/sh

cmd=$1
shift
key=$1
shift
value="$*"

ROOTDEV=/dev/sda
ROOTPART=/dev/sda
SECTOR_SIZE=512
overlay_dev=/dev/sda3

do_disk_ready() {
	local partdev
	. /lib/functions.sh
	. /lib/upgrade/common.sh
	if export_bootdevice && export_partdevice partdev 0; then
		overlay_dev=$(blkid /dev/${partdev}* 2>/dev/null | grep 'UUID="f3178596-4427-2d3b-35c7-648b65e20d5e"' | cut -d: -f1)
		test -n "$overlay_dev" || return 1
		if echo $partdev | grep -q "^sd[a-z]"; then
			ROOTDEV=/dev/${partdev}
			ROOTPART=/dev/${partdev}
		elif echo $partdev | grep -q ".*[0-9]"; then
			ROOTDEV=/dev/${partdev}
			ROOTPART=/dev/${partdev}p
		else
			ROOTDEV=/dev/${partdev}
			ROOTPART=/dev/${partdev}
		fi
		SECTOR_SIZE=`fdisk -l ${ROOTDEV} | grep "^Sector size" | awk '{print $4}'`
		return 0
	fi
	return 1
}

do_disk_ready || {
	echo diskv not ready
	exit 1
}

#echo ROOTDEV=$ROOTDEV
#echo ROOTPART=$ROOTPART
#echo $SECTOR_SIZE

set $(fdisk -l ${ROOTDEV} 2>/dev/null | grep "^${overlay_dev} " | grep -o " [1-9].*")
start=$1
end=$2

#diskv store on [overlay-64k, overlay)
START=$((start-65536/SECTOR_SIZE)) #start offset -64k
COUNT=$((65536/SECTOR_SIZE)) #size 64k
#echo START=$START
#echo COUNT=$COUNT

_start=$((start*SECTOR_SIZE/65536))
_start=$((_start*65536/SECTOR_SIZE))
if [ "$start" = "$_start" ]; then
	START=$((START*SECTOR_SIZE/65536))
	COUNT=1
	SECTOR_SIZE=65536
fi

dd if=$ROOTDEV bs=$SECTOR_SIZE skip=$START count=$COUNT of=/tmp/pd.img conv=notrunc >/dev/null 2>&1

case "$cmd" in
	get)
		value=$(cat /tmp/pd.img | grep "^$key=" | sed "s/$key=//")
		echo "$key=$value"
	;;
	set)
		cat /tmp/pd.img | grep -v "^$key=" >/tmp/pd.img.new
		test -n "$value" && echo "$key=$value" >>/tmp/pd.img.new
		cat /tmp/pd.img.new | grep = >/tmp/pd.img
		rm -f /tmp/pd.img.new
		ds=$(cat /tmp/pd.img | wc -c)
		if test $ds -gt 65536; then
			echo error, no space
			rm -f /tmp/pd.img
			exit 1
		fi
		ps=$((65536-ds))
		dd if=/dev/zero of=/tmp/pd.img bs=1 seek=$ds count=$ps >/dev/null conv=notrunc >/dev/null 2>&1
		dd if=/tmp/pd.img of=$ROOTDEV bs=$SECTOR_SIZE seek=$START count=$COUNT conv=notrunc >/dev/null 2>&1
	;;
	clearall)
		dd if=/dev/zero of=$ROOTDEV bs=$SECTOR_SIZE seek=$START count=$COUNT conv=notrunc >/dev/null 2>&1
	;;
	show)
		cat /tmp/pd.img | grep "="
	;;
	*)
		echo "usage:"
		echo "    diskv show"
		echo "    diskv get <key>"
		echo "    diskv set <key> <value>"
		echo "    diskv clearall"
	;;
esac
rm -f /tmp/pd.img

exit 0

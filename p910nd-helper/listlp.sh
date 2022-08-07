#!/bin/sh

usbmisc=/sys/class/usbmisc

cd $usbmisc && {
	for dev in $(ls); do
		path=$(realpath $dev)
		path=${path#*/sys/devices/}
		path=${path%*/usbmisc/*}
		desc_file=$usbmisc/$dev/device/ieee1284_id
		uevent_file=$usbmisc/$dev/device/uevent

		test -e $usbmisc/$dev/device/ieee1284_id || continue

		name=$(cat $desc_file | sed 's/.*DES:\(.*\);.*/\1/' | cut -d ';' -f 1)
		model=$(cat $desc_file | sed 's/.*MDL:\(.*\);.*/\1/' | cut -d ';' -f 1)
		product=`cat $uevent_file | grep PRODUCT= | sed 's/PRODUCT=\(.*\)/\1/'`

		echo "/dev/usb/$dev,$product,$model,$name,$path"
	done
}

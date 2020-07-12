#!/bin/sh

BDEV=sda
#network=172.21.170.245,255.255.240.0,172.21.175.253,8.8.8.8
network=dhcp

vmroot=/tmp/block
mkdir -p $vmroot
mount /dev/${BDEV}1 $vmroot || exit 0
cp $vmroot/x-wrt.img.gz /tmp/x-wrt.img.gz && {
	cd /
	umount $vmroot
	sync
	(zcat /tmp/x-wrt.img.gz;
	 echo network=$network;
	) >/dev/$BDEV && reboot
}

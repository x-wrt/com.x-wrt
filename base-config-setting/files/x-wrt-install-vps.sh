#!/bin/sh

vmroot=$(dirname "$0")
cp $vmroot/x-wrt.img.gz /tmp/x-wrt.img.gz && {
	(zcat /tmp/x-wrt.img.gz;
	 echo network=172.21.170.245,255.255.240.0,172.21.175.253,8.8.8.8;
	) >/dev/vda && reboot
}

#!/bin/sh

device=$1
ifname=$2
mtu=$3

ubus call network.interface.usbwan down; ubus call network.interface.usbwan up
exit 0

mkdir -p /var/run
mkfifo /var/run/quectl-$device.fifo
echo "$device $ifname $mtu" >/var/run/quectl-$device.fifo

exit 0

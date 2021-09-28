#!/bin/sh

SERVER=192.168.1.254

fw=http://$SERVER/factory_main.bin
md5=http://$SERVER/factory_main.md5

cd /tmp

while :; do
	ping -c1 $SERVER || {
		sleep 1
		continue
	}

	wget --timeout=60 -O /tmp/x-wrt.bin $fw && {
		wget --timeout=60 -O /tmp/x-wrt.bin.md5 $md5 && {
			[ "$(md5sum /tmp/x-wrt.bin | head -c32)" = "$(cat /tmp/x-wrt.bin.md5 | head -c32)" ] && {
				mtd write /tmp/x-wrt.bin firmware && {
					fw_setenv sys_boot_flag 0
				}
			}
		}
	}
done

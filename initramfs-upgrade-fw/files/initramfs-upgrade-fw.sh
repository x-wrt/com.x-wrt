#!/bin/sh

#this is an sample upgrade script, change before usage.

SERVER=192.168.1.254

fw=http://$SERVER/factory_main.bin
md5=http://$SERVER/factory_main.md5
ub=http://$SERVER/u-boot.bin

#close all led
for led in /sys/class/leds/*/brightness; do
	echo "0" >"$led"
done

. /etc/diag.sh
set_state upgrade

cd /tmp

while :; do
	ping -c1 -W1 $SERVER || {
		continue
	}

	wget --timeout=60 -O /tmp/x-wrt.bin $fw && {
		wget --timeout=60 -O /tmp/x-wrt.bin.md5 $md5 && {
			[ "$(md5sum /tmp/x-wrt.bin | head -c32)" = "$(cat /tmp/x-wrt.bin.md5 | head -c32)" ] && {
				wget --timeout=60 -O /tmp/u-boot.bin $ub && {
					mtd write /tmp/u-boot.bin u-boot
				}
				( \
					fw_setenv telnetd on; \
					test -b /dev/mmcblk0 && \
					tar xf /tmp/x-wrt.bin && \
					zcat sysupgrade-xwrt_wr1800k-ax-norplusemmc/root >/dev/mmcblk0 && \
					mtd write sysupgrade-xwrt_wr1800k-ax-norplusemmc/kernel firmware || \
					mtd write /tmp/x-wrt.bin firmware \
				) && {
					set_state done
					for led in /sys/class/leds/*/brightness; do
						echo "1" >"$led"
					done
					break
				}
				set_state failsafe
			}
		}
	}
done

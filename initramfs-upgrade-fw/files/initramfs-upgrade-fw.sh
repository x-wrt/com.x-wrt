#!/bin/sh

SERVER=192.168.1.254

fw=http://$SERVER/factory_main.bin
md5=http://$SERVER/factory_main.md5

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
				sysupgrade -T /tmp/x-wrt.bin && mtd write /tmp/x-wrt.bin firmware && {
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

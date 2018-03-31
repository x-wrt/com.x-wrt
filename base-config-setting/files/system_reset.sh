#!/bin/sh

[ x"$1" = x"-f" -o x"$1" = x"-h" ] || {
	echo "usage: $0 -f/-h"
	exit 0
}

if test -f /rom/lib/preinit/79_disk_ready; then
	sleep 1
	mount -o remount,rw /rom && rm -f /rom/etc/sda.ready
else
	sleep 1
	killall dropbear uhttpd
	test -f /etc/init.d/nginx && /etc/init.d/nginx stop
	test -f /etc/init.d/database && /etc/init.d/database stop
	sleep 1
	jffs2reset -y
fi

[ x"$1" = x"-h" ] && halt && exit 0
[ x"$1" = x"-f" ] && reboot && exit 0

exit 0

# 1. to reset config: reset /overlay: remove /rom/etc/sda.ready and reboot
# 2. to reset /data: echo erase >/dev/sda4 (it is /dev/sda6 if gpt) and reboot

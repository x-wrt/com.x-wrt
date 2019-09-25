#!/bin/sh

if test -f /rom/lib/preinit/79_disk_ready; then
	if [ x"$1" = x"-y" ] || [ x"$2" = x"-y" ]; then
		mount -o remount,rw /rom && rm -f /rom/etc/sda.ready
	fi
	if [ x"$1" = x"-r" ] || [ x"$2" = x"-r" ]; then
		sync
		reboot
	fi
else
	jffs2reset $@
fi

exit $?

# 1. to reset config: reset /overlay: remove /rom/etc/sda.ready and reboot
# 2. to reset /data: echo erase >/dev/sda4 (it is /dev/sda6 if gpt) and reboot

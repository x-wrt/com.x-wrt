#!/bin/sh

if test -f /rom/lib/preinit/79_disk_ready; then
	if [ x"$1" = x"-y" ] || [ x"$2" = x"-y" ]; then
		mount | grep overlayfs | grep -q 'workdir=/overlay/work' && {
			overlay_dev=$(df /overlay/ | tail -n1 | awk '{print $1}')
			test -b $overlay_dev && echo erase >$overlay_dev
		}
	fi
	if [ x"$1" = x"-r" ] || [ x"$2" = x"-r" ]; then
		sync
		reboot
	fi
else
	jffs2reset $@
fi

exit $?

# 1. to reset /overlay: echo erase >/dev/sda3 and reboot
# 2. to reset /data: echo erase >/dev/sda4 and reboot

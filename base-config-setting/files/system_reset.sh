#!/bin/sh

if test -f /rom/lib/preinit/79_disk_ready; then
	if [ x"$1" = x"-y" ] || [ x"$2" = x"-y" ]; then
		mount | grep overlayfs | grep -q 'workdir=/overlay/work' && {
			overlay_dev=$(df /overlay/ | tail -n1 | awk '{print $1}')
			blkid $overlay_dev 2>/dev/null | grep -q 'LABEL="extroot_overlay"' && {
				echo erase >$overlay_dev
				sync
				if [ x"$1" = x"-r" ] || [ x"$2" = x"-r" ]; then
					reboot
				fi
			}
			ubinfo $overlay_dev 2>/dev/null | grep -q "extroot_overlay" && {
				touch /overlay/.extroot-erase
				sync
				if test -x /sbin/factoryreset; then /sbin/factoryreset "$@" || jffs2reset "$@"; else jffs2reset "$@"; fi
				if [ x"$1" = x"-r" ] || [ x"$2" = x"-r" ]; then
					reboot
				fi
			}
		}
	fi
fi

if test -x /sbin/factoryreset; then /sbin/factoryreset "$@" || jffs2reset "$@"; else jffs2reset "$@"; fi

exit $?

# 1. to reset /overlay: echo erase >/dev/sda3 and reboot
# 2. to reset /data: echo erase >/dev/sda4 and reboot

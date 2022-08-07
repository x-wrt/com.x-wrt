#!/bin/sh

test -n "$vhusbd_reload" && exit 0

export vhusbd_reload=1

enabled=$(uci get vhusbd.config.enabled || echo 0)
[ "$enabled" = 0 ] && {
	/etc/init.d/vhusbd stop 2>/dev/null
	exit 0
}

test -e /usr/bin/vhusbd && {
	exit 0
}

#
#follow before exit must call /etc/init.d/vhusbd restart

#arm arm64 i386 mips mipsel x86_64
arch=
uname=$(uname -m)

case $uname in
	arm*)
		arch=arm
	;;
	mips*)
		arch=mips
		grep -qi MediaTek /proc/cpuinfo && arch=mipsel
	;;
	x86_64)
		arch=x86_64
	;;
	aarch64)
		arch=arm64
	;;
	i*86)
		arch=i386
esac

test -n "$arch" || exit 0

download_url="https://www.virtualhere.com/sites/default/files/usbserver/vhusbd$arch"

avail_size=$(df /overlay/ | tail -n1 | awk '{print $4}')
avail_size=$((avail_size+0))

# < 1M
[ $avail_size -lt $((1024+512)) ] && {
	logger -t vhusbd-online "possible no free space for vhusbd"
}

logger -t vhusbd-online "try download vhusbd from [$download_url]"

timeout 300 wget --no-check-certificate -O /tmp/vhusbd "$download_url" && {
	if chmod +x /tmp/vhusbd && cp /tmp/vhusbd /usr/bin/vhusbd; then
		logger -t vhusbd-online "download vhusbd and save to /usr/bin/vhusbd success!"
		rm -f /tmp/vhusbd
	else
		logger -t vhusbd-online "download vhusbd and save to /tmp/vhusbd success!"
		rm -f /usr/bin/vhusbd
		ln -s /tmp/vhusbd /usr/bin/vhusbd
	fi

	test -e /usr/bin/vhusbd && {
		logger -t vhusbd-online "vhusbd restart!"
		/etc/init.d/vhusbd restart 2>/dev/null
	}
}

exit 0

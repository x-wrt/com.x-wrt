#!/bin/sh

for d in feeds/packages feeds/luci feeds/routing feeds/telephony feeds/freifunk; do
	cd "$d" && {
		echo
		pwd
		echo "$@"
		eval "$@" || exit 255
		cd -
	}
done

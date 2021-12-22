#!/bin/sh

mkdir /tmp/sta_disable_lck 2>/dev/null || exit 0
sleep 45
rm -rf /tmp/sta_disable_lck

lock /tmp/sta_disable.lock

has_ap_on()
{
	local radio="$1"
	local idx=0
	while uci get wireless.@wifi-iface[$idx] >/dev/null 2>&1; do
		idx=$((idx+1))
		[ "x$(uci get wireless.@wifi-iface[$((idx-1))].mode 2>/dev/null)" = "xap" ] || continue
		[ "x$(uci get wireless.@wifi-iface[$((idx-1))].disabled 2>/dev/null)" != "x1" ] || continue
		[ "x$(uci get wireless.@wifi-iface[$((idx-1))].device 2>/dev/null)" = "x$radio" ] && return 0
	done

	return 1
}

sta_need_disable=1
for sta in $(ls /var/run/wpa_supplicant-*.conf); do
	ssid="$(cat $sta | grep ssid=\" | cut -d\" -f2)"
	iface=`echo $sta | sed 's,^/var/run/wpa_supplicant-,,;s,.conf$,,'`
	if [ $(iwinfo $iface info | grep -c 'ESSID: unknown') -ge 1 ]; then
		logger -t wifi "Fail to connect \"$ssid\""
	else
		sta_need_disable=0
	fi
done

var_revert_cmds=""
push_revert_cmds() {
	var_revert_cmds="$var_revert_cmds
$*"
}
wl_need_commit=0
if [ $sta_need_disable -eq 1 ]; then
	for sta in $(ls /var/run/wpa_supplicant-*.conf); do
		ssid="$(cat $sta | grep ssid=\" | cut -d\" -f2)"
		idx=0
		while uci get wireless.@wifi-iface[$idx] >/dev/null 2>&1; do
			idx=$((idx+1))
			[ "x$(uci get wireless.@wifi-iface[$((idx-1))].mode 2>/dev/null)" = "xsta" ] || continue
			[ "x$(uci get wireless.@wifi-iface[$((idx-1))].ssid 2>/dev/null)" = "x$ssid" ] || continue
			radio=`uci get wireless.@wifi-iface[$((idx-1))].device`
			has_ap_on $radio && [ "x$(uci get wireless.@wifi-iface[$((idx-1))].disabled 2>/dev/null)" != "x1" ] && {
				uci set wireless.@wifi-iface[$((idx-1))].disabled=1
				push_revert_cmds "uci delete wireless.@wifi-iface[$((idx-1))].disabled"
				wl_need_commit=1
			}
		done
	done

	[ "x$wl_need_commit" = "x1" ] && {
		uci commit wireless
		/etc/init.d/network reload
		sleep 5
		echo "$var_revert_cmds" | while read line; do
			$line
		done
		uci commit wireless
	}
fi

sleep 10

lock -u /tmp/sta_disable.lock

# reload network after 180s
#[ "x$wl_need_commit" = "x1" ] && {
#	mkdir /tmp/sta_disable_lck && {
#		sleep 180
#		rmdir /tmp/sta_disable_lck
#		/etc/init.d/network reload
#	}
#}

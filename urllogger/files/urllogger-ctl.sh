#!/bin/sh

QUEUE="/dev/natflow_urllogger_queue"
READER="/usr/sbin/urllogger-reader"
LOCKDIR="/tmp/urllogger.lck"

[ -c "$QUEUE" ] || exit 1
[ -x "$READER" ] || exit 1

urllogger_stop() {
	echo "0" > /proc/sys/urllogger_store/enable
	rm -rf "$LOCKDIR"
	killall urllogger-reader 2>/dev/null
	local i=0
	while pidof urllogger-reader >/dev/null 2>&1 && [ "$i" -lt 20 ]; do
		sleep 0.1 2>/dev/null || sleep 1
		i=$((i + 1))
	done
	"$READER" --clear >/dev/null 2>&1
}

urllogger_start() {
	echo "1" > /proc/sys/urllogger_store/enable
}

urllogger_read() {
	"$READER"
}

case "$1" in
	stop) urllogger_stop ;;
	start) urllogger_start ;;
	read) urllogger_read ;;
	*)
		echo "usage: $0 start|stop|read"
		exit 1
		;;
esac
exit 0

#!/bin/sh

QUEUE="/dev/natflow_urllogger_queue"
READER="/usr/sbin/urllogger-reader"
LOCKDIR="/tmp/urllogger.lck"

[ -c "$QUEUE" ] || exit 1
[ -x "$READER" ] || exit 1

urllogger_stop() {
	echo "0" > /proc/sys/urllogger_store/enable
	rm -rf "$LOCKDIR"
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

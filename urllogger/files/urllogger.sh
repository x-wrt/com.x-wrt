#!/bin/sh

LOCKDIR="/tmp/urllogger.lck"
PID="$$"
QUEUE="/dev/natflow_urllogger_queue"
READER="/usr/sbin/urllogger-reader"

[ -c "$QUEUE" ] || exit 1
[ -x "$READER" ] || exit 1

urllogger_stop() {
	echo "0" > /proc/sys/urllogger_store/enable
	rm -rf "$LOCKDIR"
	"$READER" --clear >/dev/null 2>&1
}

case "$1" in
	stop)
		urllogger_stop
		exit 0
		;;
	start)
		;;
	*)
		echo "usage: $0 start|stop"
		exit 1
		;;
esac

echo "1" > /proc/sys/urllogger_store/enable

memtotal=$(awk '/MemTotal/ {print $2; exit}' /proc/meminfo)
memtotal=${memtotal:-0}

if [ "$memtotal" -ge 1048576 ]; then
	logsize=$((16 * 1024 * 1024))
elif [ "$memtotal" -ge 524288 ]; then
	logsize=$((8 * 1024 * 1024))
elif [ "$memtotal" -ge 262144 ]; then
	logsize=$((4 * 1024 * 1024))
elif [ "$memtotal" -ge 131072 ]; then
	logsize=$((2 * 1024 * 1024))
elif [ "$memtotal" -ge 65536 ]; then
	logsize=$((1 * 1024 * 1024))
else
	logsize=$((512 * 1024))
fi

rotate_log() {
	[ -f /tmp/url.log ] || return 0
	LOGSIZE=$(wc -c < /tmp/url.log)
	if [ "$LOGSIZE" -ge "$logsize" ]; then
		NRLINE=$(wc -l < /tmp/url.log)
		NRLINE=$((NRLINE * 6 / 10))
		tail -n "$NRLINE" /tmp/url.log > /tmp/url.log.1
		mv /tmp/url.log.1 /tmp/url.log
	fi
}

main_loop() {
	"$READER" --lock "$LOCKDIR/$PID" | while IFS= read -r line; do
		[ -f "$LOCKDIR/$PID" ] || break
		rotate_log
		echo "$line" >> /tmp/url.log
	done
}

cleanup() {
	if rm -rf "$LOCKDIR"; then
		echo "Finished"
	else
		echo "Failed to remove lock directory '$LOCKDIR'"
		return 1
	fi
}

if mkdir "$LOCKDIR" >/dev/null 2>&1; then
	trap cleanup EXIT
	echo "Acquired lock, running"
	rm -f "$LOCKDIR"/*
	touch "$LOCKDIR/$PID"
	main_loop
else
	exit 0
fi

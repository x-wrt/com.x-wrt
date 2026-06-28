#!/bin/sh

LOCKDIR="/tmp/urllogger.lck"
PID="$$"

[ -c "/dev/urllogger_queue" ] || exit 1

urllogger_stop() {
	echo "0" > /proc/sys/urllogger_store/enable
	echo "clear" > /dev/urllogger_queue
	rm -rf "$LOCKDIR"
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

main_loop() {
	local time_count=0
	while :; do
		[ -f "$LOCKDIR/$PID" ] || return 0
		sleep 5
		time_count=$((time_count + 1))
		[ "$time_count" -ne 12 ] && continue
		time_count=0

		if [ -f /tmp/url.log ]; then
			LOGSIZE=$(wc -c < /tmp/url.log)
			if [ "$LOGSIZE" -ge "$logsize" ]; then
				NRLINE=$(wc -l < /tmp/url.log)
				NRLINE=$((NRLINE * 6 / 10))
				tail -n "$NRLINE" /tmp/url.log > /tmp/url.log.1
				mv /tmp/url.log.1 /tmp/url.log
			fi
		fi

		read -r UP _ < /proc/uptime
		UP=${UP%%.*}
		UP=$((UP & 0xffffffff))
		NOW=$(date +%s)

		# Note: Do not use `done < /dev/urllogger_queue`. Shell built-in `read` reads 1 byte at a time
		# which causes natflow_urllogger kernel module to return -EINVAL because the
		# buffer size (1) is smaller than the log entry size. Using `cat` bypasses this.
		cat /dev/urllogger_queue | while IFS=, read -r time data; do
			T=$((NOW + time - UP))
			T=$(date "+%Y-%m-%d %H:%M:%S" -d "@$T")
			echo "$T,$data" >> /tmp/url.log
		done
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

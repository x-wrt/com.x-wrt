#!/bin/sh

LOCKDIR="/tmp/urllogger.lck"
PID="$$"
QUEUE="/dev/natflow_urllogger_queue"
READER="/usr/sbin/urllogger-reader"

[ -c "$QUEUE" ] || exit 1
[ -x "$READER" ] || exit 1

wait_pid_exit() {
	local pid=$1
	local i=0
	[ -n "$pid" ] || return 0
	while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 10 ]; do
		usleep 100000 2>/dev/null || sleep 1
		i=$((i + 1))
	done
}

urllogger_stop() {
	echo "0" > /proc/sys/urllogger_store/enable

	local rpid=""
	local spid=""
	[ -f /var/run/urllogger-reader.pid ] && rpid=$(cat /var/run/urllogger-reader.pid)
	[ -f /var/run/urllogger.pid ] && spid=$(cat /var/run/urllogger.pid)

	rm -f /var/run/urllogger-reader.pid /var/run/urllogger.pid
	[ -n "$spid" ] && rm -f "$LOCKDIR/$spid"
	rmdir "$LOCKDIR" 2>/dev/null

	if [ -n "$rpid" ]; then
		kill -TERM "$rpid" 2>/dev/null
		wait_pid_exit "$rpid"
	fi

	if [ -n "$spid" ] && [ "$spid" -ne "$PID" ]; then
		kill -TERM "$spid" 2>/dev/null
		wait_pid_exit "$spid"
	fi

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
	local count=0
	rotate_log

	local fifo="/tmp/urllogger.fifo"
	rm -f "$fifo"
	mkfifo "$fifo" || return 1

	"$READER" --lock "$LOCKDIR/$PID" > "$fifo" 2>/dev/null &
	local rpid=$!
	echo "$rpid" > /var/run/urllogger-reader.pid

	while IFS= read -r line; do
		[ -f "$LOCKDIR/$PID" ] || break
		count=$((count + 1))
		if [ "$count" -ge 500 ]; then
			count=0
			rotate_log
		fi
		echo "$line" >> /tmp/url.log
	done < "$fifo"

	kill -TERM "$rpid" 2>/dev/null
	wait_pid_exit "$rpid"
	rm -f "$fifo" /var/run/urllogger-reader.pid
}

cleanup() {
	rm -f "$LOCKDIR/$PID"
	rm -f /var/run/urllogger-reader.pid /var/run/urllogger.pid /tmp/urllogger.fifo
	rmdir "$LOCKDIR" 2>/dev/null
	echo "Finished"
}

if mkdir "$LOCKDIR" >/dev/null 2>&1 || [ ! -d "$LOCKDIR" ]; then
	mkdir -p "$LOCKDIR"
	trap cleanup EXIT
	echo "$PID" > /var/run/urllogger.pid
	echo "Acquired lock, running"
	touch "$LOCKDIR/$PID"
	main_loop
else
	exit 0
fi

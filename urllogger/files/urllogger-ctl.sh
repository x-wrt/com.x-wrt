#!/bin/sh

QUEUE="/dev/natflow_urllogger_queue"
READER="/usr/sbin/urllogger-reader"
LOCKDIR="/tmp/urllogger.lck"

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

	if [ -n "$spid" ]; then
		kill -TERM "$spid" 2>/dev/null
		wait_pid_exit "$spid"
	fi

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

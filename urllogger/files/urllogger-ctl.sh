#!/bin/sh

QUEUE="/dev/natflow_urllogger_queue"
READER="/usr/sbin/urllogger-reader"
LOCKDIR="/tmp/urllogger.lck"

[ -c "$QUEUE" ] || exit 1
[ -x "$READER" ] || exit 1

wait_pid_exit() {
	local pid=$1
	local timeout=${2:-5}
	[ -n "$pid" ] || return 0

	local i=0
	while kill -0 "$pid" 2>/dev/null; do
		if [ "$i" -ge "$timeout" ]; then
			kill -KILL "$pid" 2>/dev/null
			sleep 1
			if kill -0 "$pid" 2>/dev/null; then
				return 1
			fi
			return 0
		fi
		sleep 1
		i=$((i + 1))
	done
	return 0
}

urllogger_stop() {
	echo "0" > /proc/sys/urllogger_store/enable

	local rpid=""
	local spid=""
	[ -f /var/run/urllogger-reader.pid ] && rpid=$(cat /var/run/urllogger-reader.pid)
	[ -f /var/run/urllogger.pid ] && spid=$(cat /var/run/urllogger.pid)

	local ok=0

	if [ -n "$rpid" ]; then
		kill -TERM "$rpid" 2>/dev/null
		if ! wait_pid_exit "$rpid" 3; then
			ok=1
		fi
	fi

	if [ -n "$spid" ]; then
		kill -TERM "$spid" 2>/dev/null
		if ! wait_pid_exit "$spid" 3; then
			ok=1
		fi
	fi

	rm -f /var/run/urllogger-reader.pid /var/run/urllogger.pid
	[ -n "$spid" ] && rm -f "$LOCKDIR/$spid"
	rmdir "$LOCKDIR" 2>/dev/null

	if ! "$READER" --clear >/dev/null 2>&1; then
		ok=1
	fi

	return $ok
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
exit $?

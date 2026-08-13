#!/bin/sh

QUEUE="/dev/natflow_urllogger_queue"
READER="/usr/sbin/urllogger-reader"
ENABLE="/proc/sys/urllogger_store/enable"
LOGFILE="/tmp/url.log"
LOCKFILE="/var/run/urllogger.lock"

reader_pid=""
runtime_dir=""
fifo=""

set_enabled() {
	printf '%s\n' "$1" > "$ENABLE"
}

stop_reader() {
	local status

	[ -n "$reader_pid" ] || return 0

	kill -TERM "$reader_pid" 2>/dev/null
	wait "$reader_pid" 2>/dev/null
	status=$?
	reader_pid=""
	return "$status"
}

cleanup() {
	local status=$?
	trap - EXIT INT TERM HUP

	stop_reader || status=1
	[ -n "$fifo" ] && rm -f "$fifo"
	[ -n "$runtime_dir" ] && rmdir "$runtime_dir" 2>/dev/null
	set_enabled 0 2>/dev/null || status=1
	"$READER" --clear >/dev/null 2>&1 || status=1
	exit "$status"
}

handle_signal() {
	exit 0
}

rotate_log() {
	[ -f "$LOGFILE" ] || return 0

	local size
	local lines
	size=$(wc -c < "$LOGFILE") || return 1
	if [ "$size" -ge "$logsize" ]; then
		lines=$(wc -l < "$LOGFILE") || return 1
		lines=$((lines * 6 / 10))
		tail -n "$lines" "$LOGFILE" > "$LOGFILE.1" || return 1
		mv "$LOGFILE.1" "$LOGFILE"
	fi
}

run_logger() {
	[ -c "$QUEUE" ] || return 1
	[ -x "$READER" ] || return 1
	[ -w "$ENABLE" ] || return 1
	command -v flock >/dev/null 2>&1 || return 1

	exec 9> "$LOCKFILE" || return 1
	flock -xn 9 || return 1

	local memtotal
	local count=0
	local reader_status
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

	trap cleanup EXIT
	trap handle_signal INT TERM HUP
	set_enabled 1 || return 1

	runtime_dir=$(mktemp -d /tmp/urllogger.XXXXXX) || return 1
	fifo="$runtime_dir/events"
	mkfifo "$fifo" || return 1
	rotate_log || return 1

	"$READER" --parent-pid "$$" > "$fifo" 2>/dev/null 9>&- &
	reader_pid=$!

	while IFS= read -r line; do
		count=$((count + 1))
		if [ "$count" -ge 500 ]; then
			count=0
			rotate_log || return 1
		fi
		printf '%s\n' "$line" >> "$LOGFILE" || return 1
	done < "$fifo"

	wait "$reader_pid"
	reader_status=$?
	reader_pid=""
	return "$reader_status"
}

case "$1" in
	run)
		run_logger
		;;
	start|stop|restart)
		exec /etc/init.d/urllogger "$1"
		;;
	*)
		echo "usage: $0 run|start|stop|restart"
		exit 1
		;;
esac

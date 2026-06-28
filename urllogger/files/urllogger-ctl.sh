#!/bin/sh

[ -c "/dev/urllogger_queue" ] || exit 1

urllogger_stop() {
	echo "0" > /proc/sys/urllogger_store/enable
	echo "clear" > /dev/urllogger_queue
}

urllogger_start() {
	echo "1" > /proc/sys/urllogger_store/enable
}

urllogger_read() {
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
		echo "$T,$data"
	done
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

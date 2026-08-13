#!/bin/sh

QUEUE="/dev/natflow_urllogger_queue"
READER="/usr/sbin/urllogger-reader"
SERVICE="/etc/init.d/urllogger"

case "$1" in
	start|stop|restart)
		exec "$SERVICE" "$1"
		;;
	read)
		[ -c "$QUEUE" ] || exit 1
		[ -x "$READER" ] || exit 1
		exec "$READER"
		;;
	*)
		echo "usage: $0 start|stop|restart|read"
		exit 1
		;;
esac

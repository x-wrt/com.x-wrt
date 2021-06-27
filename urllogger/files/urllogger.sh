#!/bin/sh

LOCKDIR=/tmp/urllogger.lck
PID=$$

urllogger_stop()
{
	echo 0 >/proc/sys/urllogger_store/enable
	echo clear >/dev/urllogger_queue
	return 0
}

test -c /dev/urllogger_queue || exit 1

[ x$1 = xstop ] && urllogger_stop && exit 0
[ x$1 = xkill ] && urllogger_stop && {
	rm -rf $LOCKDIR
	exit 0
}

[ x$1 = xstart ] || {
	echo "usage: $0 start|stop"
	exit 0
}

urllogger_start()
{
	echo 1 >/proc/sys/urllogger_store/enable
}

# start:
urllogger_start

main_loop() {
	local log_start=1
	while :; do
		test -f $LOCKDIR/$PID || return 0
		sleep 11

		LOGSIZE=$(ls -l /tmp/url.log | awk '{print $5}')
		LOGSIZE=$((LOGSIZE+0))
		if [ $log_start = 1 ]; then
			#LOGSIZE over 10MB, stop log
			if test $LOGSIZE -ge 10485760; then
				log_start=0
				urllogger_stop
				logger -t urllogger[$PID] "stop log url due to log file[/tmp/url.log] over size 10MB"
			fi
		else
			if test $LOGSIZE -lt 10485760; then
				log_start=1
				urllogger_start
				logger -t urllogger[$PID] "restart log url due to log file[/tmp/url.log] less than size 10MB"
			fi
		fi

		UP=$(cat /proc/uptime | cut -d\. -f1)
		UP=$((UP%0xffffffff))
		NOW=$(date +%s)
		cat /dev/urllogger_queue | sed 's/,/ /' | while read time data; do
			T=$((NOW+time-UP))
			T=$(date +%Y%m%d%H%M%S --date=@$T)
			echo $T,$data >>/tmp/url.log
		done
	done
}

cleanup () {
	if rm -rf $LOCKDIR; then
		echo "Finished"
	else
		echo "Failed to remove lock directory '$LOCKDIR'"
		return 1
	fi
}

if mkdir $LOCKDIR >/dev/null 2>&1; then
	trap "cleanup" EXIT

	echo "Acquired lock, running"

	rm -f $LOCKDIR/*
	touch $LOCKDIR/$PID

	main_loop
else
	exit 0
fi

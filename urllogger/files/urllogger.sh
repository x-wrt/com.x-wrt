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

# kB
memtotal=$(grep MemTotal /proc/meminfo | awk '{print $2}')
logsize=$((512*1024))
if test $memtotal -ge 1048576; then
	# > 1024M
	logsize=$((16*1024*1024))
elif test $memtotal -ge 524288; then
	# <= 1024M
	logsize=$((8*1024*1024))
elif test $memtotal -ge 262144; then
	# <= 512M
	logsize=$((4*1024*1024))
elif test $memtotal -ge 131072; then
	# <= 256M
	logsize=$((2*1024*1024))
elif test $memtotal -ge 65536; then
	# <= 128M
	logsize=$((1*1024*1024))
else
	# < 64M
	logsize=$((512*1024))
fi

main_loop() {
	local time_count=0
	while :; do
		test -f $LOCKDIR/$PID || return 0
		sleep 5
		time_count=$((time_count+1))
		test $time_count -ne 12 && continue
		time_count=0

		LOGSIZE=$(ls -l /tmp/url.log | awk '{print $5}')
		LOGSIZE=$((LOGSIZE+0))

		#LOGSIZE over $logsize, drop 1/2 log
		if test $LOGSIZE -ge $logsize; then
			NRLINE=$(cat /tmp/url.log 2>/dev/null | wc -l)
			NRLINE=$((NRLINE*6/10))
			tail -n$NRLINE /tmp/url.log >/tmp/url.log.1
			mv /tmp/url.log.1 /tmp/url.log
		fi

		UP=$(cat /proc/uptime | cut -d\. -f1)
		UP=$((UP&0xffffffff))
		NOW=$(date +%s)
		cat /dev/urllogger_queue | sed 's/,/ /' | while read time data; do
			T=$((NOW+time-UP))
			T=$(date "+%Y-%m-%d %H:%M:%S" -d @$T)
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

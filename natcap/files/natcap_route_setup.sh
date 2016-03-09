#!/bin/sh

_NAME=`basename $0`
_DIR=`dirname $0`

LOCKDIR=/tmp/$_NAME.lck

cleanup () {
	if rmdir $LOCKDIR; then
		echo "Finished"
	else
		echo "Failed to remove lock directory '$LOCKDIR'"
		exit 1
	fi
}

if mkdir $LOCKDIR 2>/dev/null; then
	trap "cleanup" EXIT

	echo "Acquired lock, running"

	"$_DIR/natcap_route_setup_no_lock.sh" $@
else
	echo "Could not create lock directory '$LOCKDIR'"
	exit 1
fi

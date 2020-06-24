#!/bin/sh

do_exit()
{
	echo fail err=$1
	exit $1
}

./for-each-do.sh git checkout -f || do_exit 255
./for-each-do.sh git fetch upstream || do_exit 255
./for-each-do.sh git pull --rebase upstream master || do_exit 255
./for-each-do.sh git status || do_exit 255
./for-each-do.sh git push --force origin master || do_exit 255

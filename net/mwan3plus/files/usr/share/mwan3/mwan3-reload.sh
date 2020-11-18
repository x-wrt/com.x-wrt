#!/bin/sh

. /lib/functions.sh
. /lib/mwan3/common.sh
. /lib/mwan3/mwan3.sh

mwan3_lock "command" "mwan3"

config_load mwan3
config_get_bool enabled globals 'enabled' '0'

mwan3_unlock "command" "mwan3"

[ "${enabled}" != 1 ] && exit 0

/etc/init.d/mwan3 restart &

exit 0

#!/bin/sh

. /lib/functions.sh

config_load mwan3
config_get_bool enabled globals 'enabled' 0
[ ${enabled} -gt 0 ] || exit 0

. /lib/mwan3/mwan3.sh

mwan3_check_family_needs
[ $NEED_IPV6 -ne 0 ] || exit 0

mwan3_lock "command" "mwan3_ipv6_masq"

mwan3_ipv6_masq_restart
LOG debug "call mwan3_ipv6_masq_restart by firewall restart"

mwan3_unlock "command" "mwan3_ipv6_masq"

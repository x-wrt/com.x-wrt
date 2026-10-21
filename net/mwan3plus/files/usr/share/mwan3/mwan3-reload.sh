#!/bin/sh

# fw3 and fw4 source this file. Do not wait for the mwan3 lock
# here: a mwan3 user hook may itself be restarting the firewall.
/usr/sbin/mwan3 firewall-reload >/dev/null 2>&1 &

exit 0

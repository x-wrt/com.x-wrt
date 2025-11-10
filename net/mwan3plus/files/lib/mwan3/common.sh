#!/bin/sh

readfile() {
	[ -f "$2" ] || return 1
	# read returns 1 on EOF
	read -d'\0' $1 <"$2" || :
}

get_uptime() {
	local _tmp
	readfile _tmp /proc/uptime
	if [ $# -eq 0 ]; then
		echo "${_tmp%%.*}"
	else
		export -n "$1=${_tmp%%.*}"
	fi
}

SCRIPTNAME="$(basename "$0")"
MWAN3_STATUS_DIR="/var/run/mwan3"
MWAN3TRACK_STATUS_DIR="/var/run/mwan3track"
LOG()
{
	local facility=$1; shift
	# in development, we want to show 'debug' level logs
	# when this release is out of beta, the comment in the line below
	# should be removed
	[ "$facility" = "debug" ] && return
	logger -t "${SCRIPTNAME}[$$]" -p $facility "$*"
}

get_online_time() {
	local time_n time_u iface family
	iface="$2"
	family="$3"
	readfile time_u "$MWAN3TRACK_STATUS_DIR/${iface}.${family}/ONLINE" 2>/dev/null
	if [ -z "${time_u}" ] || [ "${time_u}" = "0" ]; then
		export -n "$1=0"
	else
		get_uptime time_n
		export -n "$1=$((time_n-time_u))"
	fi
}

get_offline_time() {
	local time_n time_d iface family
	iface="$2"
	family="$3"
	readfile time_d "$MWAN3TRACK_STATUS_DIR/${iface}.${family}/OFFLINE" 2>/dev/null
	if [ -z "${time_d}" ] || [ "${time_d}" = "0" ]; then
		export -n "$1=0"
	else
		get_uptime time_n
		export -n "$1=$((time_n-time_d))"
	fi
}

get_age() {
	local time_p time_u
	iface="$2"
	family="$3"
	readfile time_p "$MWAN3TRACK_STATUS_DIR/${iface}.${family}/TIME" 2>/dev/null
	if [ -z "${time_p}" ]; then
		export -n "$1=0"
	else
		get_uptime time_n
		export -n "$1=$((time_n-time_p))"
	fi
}

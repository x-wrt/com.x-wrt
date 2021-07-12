#!/bin/sh

get_uptime() {
	local uptime=$(cat /proc/uptime)
	echo "${uptime%%.*}"
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
	iface="$1"
	family="$2"
	time_u="$(cat "$MWAN3TRACK_STATUS_DIR/${iface}.${family}/ONLINE" 2>/dev/null)"
	[ -z "${time_u}" ] || [ "${time_u}" = "0" ] || {
		time_n="$(get_uptime)"
		echo $((time_n-time_u))
	}
}

get_offline_time() {
	local time_n time_d iface family
	iface="$1"
	family="$2"
	time_d="$(cat "$MWAN3TRACK_STATUS_DIR/${iface}.${family}/OFFLINE" 2>/dev/null)"
	[ -z "${time_d}" ] || [ "${time_d}" = "0" ] || {
		time_n="$(get_uptime)"
		echo $((time_n-time_d))
	}
}

get_age() {
	local time_p time_u
	iface="$1"
	family="$2"
	time_p="$(cat "$MWAN3TRACK_STATUS_DIR/${iface}.${family}/TIME" 2>/dev/null)"
	[ -z "${time_p}" ] || {
		time_n="$(get_uptime)"
		echo $((time_n-time_p))
	}
}

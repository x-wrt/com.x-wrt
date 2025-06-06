#!/bin/sh

wifi_setup_radio()
{
	local radio=$1

	if uci get wireless.${radio} >/dev/null 2>&1; then
		#FIXME hack
		local path htmode
		if [ "${radio}" = "radio0" ] || [ "${radio}" = "radio1" ]; then
		if test -e /sys/kernel/debug/ieee80211/phy0/mt76 &&
		   [ "$(readlink /sys/class/ieee80211/phy0/device)" = "$(readlink /sys/class/ieee80211/phy1/device)" ]; then
			htmode="$(uci get wireless.${radio}.htmode)"
			path="$(uci get wireless.${radio}.path)"
			if test -z "${htmode##HE*}"; then
				htmode=HE
			else
				htmode=
			fi
			if test -z "${path#*+1}"; then
				uci set wireless.${radio}.phy='phy1'
				uci set wireless.${radio}.htmode="${htmode:-VHT}80"
				uci set wireless.${radio}.hwmode='11a'
				uci set wireless.${radio}.band='5g'
			else
				uci set wireless.${radio}.phy='phy0'
				uci set wireless.${radio}.htmode="${htmode:-HT}20"
				uci set wireless.${radio}.hwmode='11g'
				uci set wireless.${radio}.band='2g'
			fi
			uci delete wireless.${radio}.path
		fi
		fi # radio0/radio1

		uci -q batch <<-EOT
			set wireless.${radio}.disabled='0'
			set wireless.${radio}.country='CN'
			set wireless.${radio}.channel='auto'
			set wireless.${radio}.cell_density='0'
		EOT

		if [ "$(uci get wireless.${radio}.band 2>/dev/null)" = "2g" ] || [ "$(uci get wireless.${radio}.band 2>/dev/null)" = "5g" ]; then
			htmode="$(uci get wireless.${radio}.htmode 2>/dev/null)"
			if [ "${htmode//EHT}" != "${htmode}" ]; then
				if  [ "$(uci get wireless.${radio}.band 2>/dev/null)" = "2g" ]; then
					uci set wireless.${radio}.channel="1"
				else
					uci set wireless.${radio}.channel="36"
				fi
			fi
		elif uci get wireless.${radio}.htmode 2>/dev/null | grep -q EHT; then
			uci set wireless.${radio}.country='DE'
			uci set wireless.${radio}.channel='21'
			uci set wireless.${radio}.band='6g'
		fi

		obj=$(uci add wireless wifi-iface)
		if test -n "$obj"; then
			uci set wireless.$obj.device="${radio}"
			uci set wireless.$obj.network='lan'
			uci set wireless.$obj.mode='ap'
			uci set wireless.$obj.ssid="${SSID}"
			uci set wireless.$obj.encryption='psk2'
			uci set wireless.$obj.key="${SSID_PASSWD}"
			if uci get wireless.${radio}.path | grep -q bcma || iwinfo wlan${radio:5} info | grep -qi Cypress; then
				if [ "$(uci get wireless.${radio}.band)" = "2g" ]; then
					uci set wireless.${radio}.channel='1'
				else
					uci set wireless.${radio}.channel='36'
				fi
			else
				uci set wireless.$obj.ieee80211r='1'
				uci set wireless.$obj.ft_over_ds='0'
				uci set wireless.$obj.ft_psk_generate_local='1'
			fi


			if [ "$(uci get wireless.${radio}.band 2>/dev/null)" = "6g" ]; then
				uci set wireless.$obj.encryption='sae'
				uci set wireless.$obj.ocv='0'
				uci set wireless.$obj.ssid="${SSID}_6G"
				uci delete wireless.$obj.ft_psk_generate_local
			fi
			if [ "$(uci get wireless.${radio}.band 2>/dev/null)" = "5g" ] && test -e /sys/kernel/debug/ieee80211/phy0/mt76; then
				obj=$(uci add wireless wifi-iface)
				if test -n "$obj"; then
					uci set wireless.$obj.device="${radio}"
					uci set wireless.$obj.network='lan'
					uci set wireless.$obj.mode='ap'
					uci set wireless.$obj.ssid="${SSID}_5G"
					uci set wireless.$obj.encryption='psk2'
					uci set wireless.$obj.key="${SSID_PASSWD}"
					uci set wireless.$obj.ieee80211r='1'
					uci set wireless.$obj.ft_over_ds='0'
					uci set wireless.$obj.ft_psk_generate_local='1'
					uci set wireless.$obj.subfix="_5G"
				fi
			fi
		fi
	fi
}

wifi_first_init()
{
	SSID="${SSID-$(uci get base_config.@status[0].SSID 2>/dev/null || echo X-WRT)}"
	SSID_PASSWD="${SSID_PASSWD-$(uci get base_config.@status[0].SSID_PASSWD 2>/dev/null || echo 88888888)}"

	while uci delete wireless.@wifi-iface[0] >/dev/null 2>&1; do :; done
	for radio in radio0 radio1 radio2 radio3 wifi0 wifi1 wifi2 wifi3; do
		wifi_setup_radio ${radio}
	done
	uci commit wireless

	# wireless migration
	local widx=0
	local change=0
	while uci rename wireless.@wifi-iface[$widx]=wifinet$widx >/dev/null 2>&1; do widx=$((widx+1)); done
	uci changes wireless | tr ".='" "   " | while read _ a b; do
		if [ "x$a" != "x$b" ]; then
			uci commit wireless
			change=1
			break
		fi
	done
	[ "x$change" = "x0" ] && uci revert wireless
}

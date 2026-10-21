#!/bin/sh

wifi_get_phy()
{
	local radio=$1
	local phy="$(uci get wireless.${radio}.phy 2>/dev/null)"

	if [ -n "$phy" ] && [ -d "/sys/class/ieee80211/$phy" ]; then
		echo "$phy"
		return 0
	fi

	local path="$(uci get wireless.${radio}.path 2>/dev/null)"
	local offset=0 p index
	if [ -n "$path" ]; then
		# OpenWrt path +N selects the Nth PHY in wiphy index order.
		case "$path" in
			*+*) offset="${path##*+}"; path="${path%+*}" ;;
		esac
		[ -n "$path" ] || return 1
		case "$offset" in
			''|*[!0-9]*) return 1 ;;
		esac

		phy="$(
			for p in /sys/class/ieee80211/*; do
				[ -d "$p" ] || continue
				case "$(readlink -f "$p/device" 2>/dev/null)" in
					*"$path")
						index="$(cat "$p/index" 2>/dev/null)"
						case "$index" in
							''|*[!0-9]*) continue ;;
						esac
						printf '%s %s\n' "$index" "${p##*/}"
						;;
				esac
			done | sort -n | awk -v offset="$offset" 'NR == offset + 1 { print $2; exit }'
		)"
		if [ -n "$phy" ]; then
			echo "$phy"
			return 0
		fi
	fi

	local num="${radio#radio}"
	[ "$num" = "$radio" ] && num="${radio#wifi}"
	if [ -n "$num" ] && [ "$num" != "$radio" ] && [ -d "/sys/class/ieee80211/phy$num" ]; then
		echo "phy$num"
		return 0
	fi

	return 1
}

wifi_is_mt76()
{
	local phy=$1
	[ -z "$phy" ] && return 1

	test -e "/sys/kernel/debug/ieee80211/$phy/mt76" && return 0

	case "$(readlink /sys/class/ieee80211/$phy/device/driver 2>/dev/null)" in
		*mt7*) return 0 ;;
	esac

	return 1
}

wifi_is_single_bss()
{
	local phy=$1
	[ -z "$phy" ] && return 1

	# 1. 优先通过 iw 检查 AP 组合限制是否为 1 (通用判断)
	if command -v iw >/dev/null 2>&1 && iw phy "$phy" info 2>/dev/null | grep -qE '#\{ AP \} <= 1([[:space:],]|$)'; then
		return 0
	fi

	# 2. 检查驱动：mt792x 系列 (MT7921/MT7922/MT7925 等客户端芯片) 仅支持 1 个 AP BSS
	case "$(readlink /sys/class/ieee80211/$phy/device/driver 2>/dev/null)" in
		*mt792*) return 0 ;;
	esac

	# 3. 检查 debugfs 特征节点 (mt792x 独有的 deep-sleep 节点)
	if test -e "/sys/kernel/debug/ieee80211/$phy/mt76/deep-sleep"; then
		return 0
	fi

	return 1
}

wifi_is_cypress()
{
	local phy=$1
	local radio=$2

	case "$(uci get wireless.${radio}.path 2>/dev/null)" in
		*bcma*|*brcm*|*bcm*) return 0 ;;
	esac

	[ -z "$phy" ] && return 1

	case "$(readlink /sys/class/ieee80211/$phy/device/driver 2>/dev/null)" in
		*brcm*|*b43*|*bcma*) return 0 ;;
	esac

	case "$(cat /sys/class/ieee80211/$phy/device/vendor 2>/dev/null)" in
		0x02d0|0x14e4) return 0 ;;
	esac

	if command -v iwinfo >/dev/null 2>&1; then
		if iwinfo "$phy" info 2>/dev/null | grep -qiE 'Cypress|Broadcom'; then
			return 0
		fi
		local idx="${radio#radio}"
		[ "$idx" = "$radio" ] && idx="${radio#wifi}"
		if [ -n "$idx" ] && [ "$idx" != "$radio" ] && iwinfo "wlan$idx" info 2>/dev/null | grep -qiE 'Cypress|Broadcom'; then
			return 0
		fi
	fi

	return 1
}

wifi_setup_radio()
{
	local radio=$1
	local phy="$(wifi_get_phy "$radio")"

	if uci get wireless.${radio} >/dev/null 2>&1; then
		#FIXME hack
		local path htmode
		if [ "${radio}" = "radio0" ] || [ "${radio}" = "radio1" ]; then
		if [ -e "/sys/class/ieee80211/phy0/device" ] && [ -e "/sys/class/ieee80211/phy1/device" ] &&
		   [ "$(readlink /sys/class/ieee80211/phy0/device)" = "$(readlink /sys/class/ieee80211/phy1/device)" ] &&
		   wifi_is_mt76 "phy0"; then
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
			phy="$(wifi_get_phy "$radio")"
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
			if [ "$htmode" = "NOHT" ] || [ -z "$htmode" ]; then
				if [ "$(uci get wireless.${radio}.band 2>/dev/null)" = "2g" ]; then
					htmode='HT20'
				else
					local htmodes
					if command -v iwinfo >/dev/null 2>&1 && [ -n "$phy" ]; then
						htmodes="$(iwinfo "$phy" htmodelist 2>/dev/null)"
					fi
					case "$htmodes" in
						*VHT80*) htmode='VHT80' ;;
						*HT40*) htmode='HT40' ;;
						*HT20*) htmode='HT20' ;;
						*) htmode='VHT80' ;;
					esac
				fi
				uci set wireless.${radio}.htmode="$htmode"
			fi
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
			if wifi_is_cypress "$phy" "${radio}"; then
				if [ "$(uci get wireless.${radio}.band 2>/dev/null)" = "2g" ] || [ "$(uci get wireless.${radio}.hwmode 2>/dev/null)" = "11g" ]; then
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
			if [ "$(uci get wireless.${radio}.band 2>/dev/null)" = "5g" ] && wifi_is_mt76 "$phy" && ! wifi_is_single_bss "$phy"; then
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
	change=0
	while read -r _ a b; do
		if [ "x$a" != "x$b" ]; then
			change=1
			break
		fi
	done <<EOT
$(uci changes wireless | tr ".='" "   ")
EOT
	if [ "x$change" = "x1" ]; then
		uci commit wireless
	else
		uci revert wireless
	fi
}

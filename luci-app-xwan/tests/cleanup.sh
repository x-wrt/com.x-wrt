#!/bin/sh
# Run on OpenWrt: sh luci-app-xwan/tests/cleanup.sh
# Uses only synthetic config in a private directory; never reloads services.
set -eu

PACKAGE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INIT=${1:-$PACKAGE/files/root/etc/init.d/xwan}
MODEL=${2:-$PACKAGE/files/luci/model/cbi/xwan/xwan.lua}
MWAN_LIB=${3:-$PACKAGE/../net/mwan3plus/files/lib/mwan3/mwan3.sh}
MWAN_DEFAULTS=${4:-$PACKAGE/../net/mwan3plus/files/etc/config/mwan3}
ROOT=$(mktemp -d /tmp/xwan-test.XXXXXX)
trap 'rm -rf "$ROOT"' EXIT HUP INT TERM
mkdir -p "$ROOT/config" "$ROOT/delta" "$ROOT/overrides" "$ROOT/bin"
export XWAN_TEST_ROOT="$ROOT"
export PATH="$ROOT/bin:$PATH"
cat > "$ROOT/bin/uci" <<'EOF'
#!/bin/sh
case "${XWAN_TEST_FAILURE:-}:$*" in
	write:*"set network.dev_xwand01.mode="*) exit 1 ;;
	commit:*"commit firewall"*) exit 1 ;;
	concurrent:*"set network.dev_xwand01.mode="*)
		/sbin/uci -c "$XWAN_TEST_ROOT/config" -t "$XWAN_TEST_ROOT/delta" set network.concurrent=interface
		;;
esac
exec /sbin/uci -c "$XWAN_TEST_ROOT/config" -C "$XWAN_TEST_ROOT/overrides" -t "$XWAN_TEST_ROOT/delta" "$@"
EOF
chmod +x "$ROOT/bin/uci"

fail() { echo "FAIL: $*" >&2; exit 1; }
present() { uci -q get "$1" >/dev/null || fail "$1 missing"; }
absent() { ! uci -q get "$1" >/dev/null || fail "$1 still present"; }
equal() { [ "$(uci -q get "$1")" = "$2" ] || fail "$1 differs from $2"; }
# Redirect reloads to sinks even when exercising restart/failure paths.
mkdir "$ROOT/services"
for service in network firewall mwan3; do
	cat > "$ROOT/services/$service" <<'EOF'
#!/bin/sh
printf '%s %s\n' "${0##*/}" "$*" >> "$XWAN_TEST_ROOT/reloads"
EOF
	chmod +x "$ROOT/services/$service"
done
sed -e "s|/etc/init.d/|$ROOT/services/|g" \
	-e "s|/etc/config/|$ROOT/config/|g" \
	-e "s|/var/lock/xwan-config.lock|$ROOT/xwan-config.lock|g" "$INIT" > "$ROOT/xwan"
INIT="$ROOT/xwan"
invoke() {
	# Use the real OpenWrt config parser with the isolated UCI CLI above.
	# config_load normally calls /sbin/uci with the system delta directory.
	sh -c '
		. /lib/functions.sh
		config_load() {
			local data
			data=$(uci -n export "$1") || return
			eval "$data"
		}
		. "$1"
		start
	' sh "$INIT"
}
run() {
	invoke || fail 'xwan returned failure'
	[ -z "$(uci changes)" ] || fail 'uncommitted changes remain'
}
reject() {
	local before pending
	before=$(md5sum "$ROOT/config/"*)
	pending=$(uci changes)
	: > "$ROOT/reloads"
	if XRELOAD=1 invoke; then fail 'invalid run reported success'; fi
	[ "$before" = "$(md5sum "$ROOT/config/"*)" ] || fail 'rejected run changed committed config'
	[ "$pending" = "$(uci changes)" ] || fail 'rejected run changed pending user edits'
	[ ! -s "$ROOT/reloads" ] || fail 'rejected run reloaded services'
}
reset() {
	rm -f "$ROOT/config/"* "$ROOT/delta/"*
	touch "$ROOT/config/network" "$ROOT/config/firewall" "$ROOT/config/mwan3" "$ROOT/config/xwan"
	uci batch <<'EOF'
set network.wand=interface
set network.wand.device='lan4'
set network.wand.proto='pppoe'
set network.wand.metric='40'
set network.wanc=interface
set network.wanc.ifname='lan3'
set network.wanc.proto='pppoe'
set network.wanc.metric='50'
set firewall.wan=zone
set firewall.wan.name='wan'
add_list firewall.wan.network='wand'
add_list firewall.wan.network='wanc'
set mwan3.globals=globals
set xwan.d=xwan
set xwan.d.interface='wand'
set xwan.d.enabled='1'
set xwan.d.number='5'
set xwan.d.balanced='1'
set xwan.d.family='ipv4'
set xwan.c=xwan
set xwan.c.interface='wanc'
set xwan.c.enabled='1'
set xwan.c.number='5'
set xwan.c.balanced='1'
set xwan.c.family='ipv6'
commit
EOF
}
group_present() {
	present "mwan3.$1"
	for id in 01 02 03 04; do
		present "network.x$1$id"
		present "network.dev_x$1$id"
		present "mwan3.x$1$id"
		present "mwan3.xwan_x$1${id}_m100_w100"
	done
}
group_absent() {
	absent "mwan3.$1"
	absent "mwan3.xwan_$1_m100_w100"
	for id in 01 02 03 04; do
		absent "network.x$1$id"
		absent "network.dev_x$1$id"
		absent "mwan3.x$1$id"
		absent "mwan3.xwan_x$1${id}_m100_w100"
		case " $(uci get firewall.wan.network) " in
			*" x$1$id "*) fail 'stale firewall membership' ;;
		esac
	done
}

reset
XRELOAD=1 run
[ "$(cat "$ROOT/reloads")" = "$(printf 'network reload\nfirewall reload\nmwan3 reload')" ] || fail 'changed run did not reload expected services'
group_present wand
group_present wanc
equal mwan3.xwan_balanced.use_member 'xwan_wand_m100_w100 xwan_xwand01_m100_w100 xwan_xwand02_m100_w100 xwan_xwand03_m100_w100 xwan_xwand04_m100_w100 xwan_wanc_m100_w100 xwan_xwanc01_m100_w100 xwan_xwanc02_m100_w100 xwan_xwanc03_m100_w100 xwan_xwanc04_m100_w100'
equal mwan3.xwanc01.family ipv6
absent mwan3.xwan_balanced_v6
absent mwan3.xwan_https_quic
equal mwan3.xwan_https.sticky 1
equal mwan3.xwan_https.family ipv4
equal mwan3.xwan_https_v6.family ipv6
equal mwan3.xwan_default.family ipv4
equal mwan3.xwan_default_v6.family ipv6
before=$(md5sum "$ROOT/config/"*)
: > "$ROOT/reloads"
XRELOAD=1 run
[ ! -s "$ROOT/reloads" ] || fail 'unchanged start reloaded services'
[ "$before" = "$(md5sum "$ROOT/config/"*)" ] || fail 'unchanged start rewrites config'
echo 'PASS: two sources, original policy behavior, idempotent start'

uci set network.xwand01.password='separate-test-account'
uci set network.xwand01.mtu=1480
uci add_list network.xwand01.dns=192.0.2.53
uci add_list network.xwand01.dns=192.0.2.54
uci commit network
wand_before=$(uci show network.xwand01; uci show mwan3.xwand01)
uci set xwan.c.enabled=0
uci commit xwan
run
group_present wand
group_absent wanc
[ "$wand_before" = "$(uci show network.xwand01; uci show mwan3.xwand01)" ] || fail 'active group changed'
uci set xwan.c.enabled=1
uci commit xwan
run
group_present wanc
uci delete xwan.c
uci commit xwan
run
group_present wand
group_absent wanc
uci set xwan.d.number=2
uci commit xwan
run
present network.xwand01
absent network.xwand02
absent mwan3.xwand02
uci set xwan.d.balanced=0
uci commit xwan
run
present network.xwand01
absent mwan3.wand
for section in xwan_balanced xwan_https xwan_https_v6 xwan_default xwan_default_v6; do
	absent "mwan3.$section"
done
uci delete xwan.d
uci commit xwan
run
group_absent wand
equal firewall.wan.network 'wand wanc'
echo 'PASS: disable/delete one group, reduce count, turn balancing off, delete all'

reset
# Deliberate collisions with old generic names AND source/member names.
uci batch <<'EOF'
set mwan3.balanced=policy
set mwan3.balanced.last_resort='blackhole'
set mwan3.https=rule
set mwan3.https.proto='udp'
set mwan3.https.use_policy='balanced'
set mwan3.default_rule=rule
set mwan3.default_rule.use_policy='balanced'
set mwan3.default_rule_v4=rule
set mwan3.default_rule_v4.use_policy='balanced'
set mwan3.default_rule_v6=rule
set mwan3.default_rule_v6.use_policy='balanced'
set mwan3.wand=interface
set mwan3.wand.enabled='0'
set mwan3.wand.interval='77'
set mwan3.wand_m100_w100=member
set mwan3.wand_m100_w100.weight='7'
set mwan3.wand_m100_w100.interface='wand'
set mwan3.xwan_wanc_m100_w100=member
set mwan3.xwan_wanc_m100_w100.interface='wanc'
commit mwan3
EOF
manual=$(uci export mwan3)
run
equal mwan3.wand.interval 77
equal mwan3.wand.enabled 0
uci delete xwan.d
uci delete xwan.c
uci commit xwan
run
[ "$manual" = "$(uci export mwan3)" ] || fail 'user mwan3 configuration changed'
echo 'PASS: generic/source/member name collisions survive apply and cleanup unchanged'

reset
uci set mwan3.xwan_balanced=policy
uci set mwan3.xwan_balanced.last_resort=blackhole
uci commit mwan3
run
equal mwan3.xwan_balanced.last_resort blackhole
absent mwan3.wand
absent mwan3.xwan_https
present network.xwand01
echo 'PASS: an unowned namespaced policy blocks automatic balancing safely'

reset
# Old, unmarked generated sections and pre-existing firewall membership.
uci batch <<'EOF'
set network.xwand01=interface
set network.xwand01.proto='static'
set network.dev_xwand01=device
set network.dev_xwand01.name='keep_me'
set network.device01=device
set network.device01.name='mvlan01'
set network.xwan01=interface
set network.xwan01.ifname='mvlan01'
add_list firewall.wan.network='xwand01'
add_list firewall.wan.network='xwand02'
commit
EOF
legacy=$(uci show network.xwand01; uci show network.dev_xwand01; uci show network.device01; uci show network.xwan01)
reject
absent mwan3.xwand01
uci delete xwan.d
uci delete xwan.c
uci commit xwan
run
[ "$legacy" = "$(uci show network.xwand01; uci show network.dev_xwand01; uci show network.device01; uci show network.xwan01)" ] || fail 'unmarked legacy configuration changed'
equal firewall.wan.network 'wand wanc xwand01 xwand02'
echo 'PASS: unmarked legacy sections and pre-existing firewall entries are retained'

reset
run
before=$(md5sum "$ROOT/config/network" "$ROOT/config/firewall" "$ROOT/config/mwan3")
rm "$ROOT/config/xwan"
if XRELOAD= sh -c '
	. /lib/functions.sh
	config_load() { return 1; }
	. "$1"
	start
' sh "$INIT"; then
	fail 'failed config load was ignored'
fi
[ "$before" = "$(md5sum "$ROOT/config/network" "$ROOT/config/firewall" "$ROOT/config/mwan3")" ] || fail 'failed load changed managed state'
echo 'PASS: failed config load does not clean existing state'

reset
uci set mwan3.xwan_balanced=policy
uci commit mwan3
run
absent mwan3.xwan_https
uci delete mwan3.xwan_balanced
uci commit mwan3
run
group_present wand
present mwan3.xwan_https
uci delete network.xwand02
uci delete network.dev_xwand03
uci delete mwan3.xwan_https
uci commit
run
group_present wand
present mwan3.xwan_https
echo 'PASS: clearing a conflict or removing generated state is repaired on the next start'

reset
uci set xwan.c.enabled=0
uci set xwan.d.number=1
uci set mwan3.wand=interface
uci set mwan3.wand.enabled=1
uci set mwan3.xwan_wand_m100_w100=member
uci set mwan3.xwan_wand_m100_w100.interface=wand
uci commit
run
for section in xwan_balanced xwan_https xwan_https_v6 xwan_default xwan_default_v6; do
	absent "mwan3.$section"
done
uci delete mwan3.xwan_wand_m100_w100
uci commit mwan3
run
present mwan3.xwan_default
uci set mwan3.wand.enabled=0
uci commit mwan3
run
absent mwan3.xwan_balanced
equal mwan3.wand.enabled 0
echo 'PASS: zero eligible members never publish automatic rules, and disabled user tracking stays disabled'

reset
uci set xwan.c.enabled=0
uci set xwan.d.interface=later
uci commit xwan
reject
absent network.xlater01
uci set network.later=interface
uci set network.later.device=lan2
uci set network.later.proto=dhcp
uci commit network
run
present network.xlater01
echo 'PASS: a previously missing source is picked up without editing xwan config'

for long_source in internet wan_unicom_1; do
	reset
	uci set xwan.c.enabled=0
	uci set xwan.d.interface=$long_source
	uci set xwan.d.number=3
	uci set network.$long_source=interface
	uci set network.$long_source.device=lan4
	uci set network.$long_source.proto=pppoe
	uci commit
	run
	count=0
	for section in $(uci -q -X show network | sed -n 's/^network\.\([^.=]*\)=interface$/\1/p'); do
		[ "$(uci -q get network.$section.xwan_source)" = $long_source ] || continue
		dev=$(uci get network.$section.device)
		[ ${#dev} -le 15 ] || fail 'overlong macvlan name'
		[ ${#section} -le 13 ] || fail 'overlong mwan3 interface name'
		[ $((6 + ${#section})) -le 15 ] || fail 'overlong generated PPPoE name'
		count=$((count + 1))
	done
	[ "$count" = 2 ] || fail 'long source did not create two derived interfaces'
done
echo 'PASS: medium and long source names fit macvlan, PPPoE and mwan3 limits'

reset
# Use the package's real defaults, which already contain catch-all rules.
uci import mwan3 < "$MWAN_DEFAULTS"
uci set mwan3.manual_dns=rule
uci set mwan3.manual_dns.proto=udp
uci set mwan3.manual_dns.dest_port=53
uci set mwan3.manual_dns.use_policy=wan_only
uci reorder mwan3.manual_dns=0
uci commit mwan3
manual=$(uci export mwan3)
run
rule_position() {
	uci -q -X show mwan3 | sed -n 's/^mwan3\.\([^.=]*\)=rule$/\1/p' |
		awk -v name="$1" '$0 == name { print NR }'
}
[ "$(rule_position manual_dns)" -lt "$(rule_position xwan_https)" ] || fail 'specific user rule lost precedence'
[ "$(rule_position xwan_https)" -lt "$(rule_position https)" ] || fail 'old HTTPS rule hides xwan'
[ "$(rule_position xwan_default)" -lt "$(rule_position default_rule_v4)" ] || fail 'old IPv4 default hides xwan'
[ "$(rule_position xwan_default_v6)" -lt "$(rule_position default_rule_v6)" ] || fail 'old IPv6 default hides xwan'
before=$(md5sum "$ROOT/config/"*)
run
[ "$before" = "$(md5sum "$ROOT/config/"*)" ] || fail 'rule reordering is not idempotent'

# Execute the actual mwan3plus rule compiler with command sinks. No iptables,
# ipset or network command is run, but length checks and emitted rules are real.
compile_rules() {
	: > "$ROOT/compiled-rules"
	sed -n '/^mwan3_set_user_iptables_rule()/,/^}/p' "$MWAN_LIB" > "$ROOT/compiler.sh"
	export XWAN_TEST_TRACE="$ROOT/compiled-rules"
	sh -c '
		. /lib/functions.sh
		data=$(uci -n export mwan3) || exit 1
		eval "$data"
		. "$1"
		NEED_IPV4=1; NEED_IPV6=1; MMX_MASK=0x3F00
		IPS=:
		current=
		mwan3_push_update() { printf "%s %s\n" "$ipv" "$*" >> "$XWAN_TEST_TRACE"; }
		LOG() { printf "LOG %s\n" "$*" >> "$XWAN_TEST_TRACE"; }
		mwan3_set_sticky_iptables() { :; }
		for ipv in ipv4 ipv6; do
			config_foreach mwan3_set_user_iptables_rule rule "$ipv"
		done
	' sh "$ROOT/compiler.sh"
}
compile_rules
! grep -q 'exceeds max' "$XWAN_TEST_TRACE" || fail 'mwan3 rejected an automatic rule name'
grep -q -- '-d 0.0.0.0/0 .*mwan3_policy_xwan_balanced' "$XWAN_TEST_TRACE" || fail 'IPv4 default was not compiled'
grep -q -- '-d ::/0 .*mwan3_policy_xwan_balanced' "$XWAN_TEST_TRACE" || fail 'IPv6 default was not compiled'
grep -q -- 'ipv4 .*--dports 443 .* -j mwan3_rule_xwan_https$' "$XWAN_TEST_TRACE" || fail 'IPv4 HTTPS rule was not compiled'
grep -q -- 'ipv6 .*--dports 443 .* -j mwan3_rule_xwan_https_v6$' "$XWAN_TEST_TRACE" || fail 'IPv6 HTTPS rule was not compiled'
uci delete xwan.d
uci delete xwan.c
uci commit xwan
run
[ "$manual" = "$(uci export mwan3)" ] || fail 'user rule contents/order were not restored exactly'
echo 'PASS: bundled defaults, specific user rules, real IPv4/IPv6 rule compilation, and cleanup'

reset
rm "$ROOT/config/mwan3"
: > "$ROOT/reloads"
XRELOAD=1 run
! grep -q mwan3 "$ROOT/reloads" || fail 'missing mwan3 was reloaded'
present network.xwand01
present network.xwanc01
[ ! -e "$ROOT/config/mwan3" ] || fail 'optional mwan3 config was created'
uci delete xwan.c
uci commit xwan
run
present network.xwand01
absent network.xwanc01
echo 'PASS: creating and cleaning interfaces works without optional mwan3'

# Failed enabled groups must never become candidates for cleanup.
reset
run
uci set network.xwand04.password=isolated-custom-account
uci set network.dev_xwand01=interface
uci commit network
reject
equal network.xwand04.password isolated-custom-account
group_present wanc
uci set network.dev_xwand01=device
uci commit network
run
for invalid in missing-source duplicate-source invalid-count; do
	case "$invalid" in
		missing-source) uci set xwan.d.interface=missing ;;
		duplicate-source) uci set xwan.d.interface=wanc ;;
		invalid-count) uci set xwan.d.number=0 ;;
	esac
	uci commit xwan
	reject
	uci set xwan.d.interface=wand
	uci set xwan.d.number=5
	uci commit xwan
done
echo 'PASS: early-group type/input errors preserve both groups and credentials'

# Inject a UCI mutation failure after some writes have already been staged.
uci set network.dev_xwand01.mode=bridge
uci commit network
XWAN_TEST_FAILURE=write reject
run
for package in network firewall mwan3 xwan; do
	uci set "$package.staging_only=marker"
	reject
	uci revert "$package"
done
echo 'PASS: mutation failures discard only private deltas; pending user edits are untouched'

# A user edit arriving during generation also aborts without consuming it.
uci set network.dev_xwand01.mode=bridge
uci commit network
before=$(md5sum "$ROOT/config/"*)
if XWAN_TEST_FAILURE=concurrent invoke; then fail 'concurrent edit ignored'; fi
[ "$before" = "$(md5sum "$ROOT/config/"*)" ] || fail 'concurrent edit caused a commit'
equal network.concurrent interface
uci revert network
run
echo 'PASS: edits arriving during generation prevent commit'

# Native UCI cannot atomically commit three packages. Report the error, stop
# before subsequent commits/reloads, and allow the next start to reconcile.
reset
: > "$ROOT/reloads"
if XWAN_TEST_FAILURE=commit XRELOAD=1 invoke; then fail 'commit error ignored'; fi
[ ! -s "$ROOT/reloads" ] || fail 'commit error reloaded services'
[ -z "$(uci changes)" ] || fail 'commit error leaked private deltas'
present network.xwand01
absent mwan3.xwan_balanced
run
group_present wand
group_present wanc
echo 'PASS: partial commit is reported without reload; retry reconciles successfully'

reset
uci batch <<'EOF'
set mwan3.old_v4=rule
set mwan3.old_v4.family=ipv4
set mwan3.old_v4.dest_ip='0.0.0.0/0'
set mwan3.old_v4.use_policy=default
set mwan3.office_v6=rule
set mwan3.office_v6.family=ipv6
set mwan3.office_v6.src_ip='2001:db8::100/128'
set mwan3.office_v6.proto=tcp
set mwan3.office_v6.dest_port=443
set mwan3.office_v6.use_policy=default
set mwan3.old_v6=rule
set mwan3.old_v6.family=ipv6
set mwan3.old_v6.dest_ip='::/0'
set mwan3.old_v6.use_policy=default
commit mwan3
EOF
# Match representative packets against rules emitted by the real compiler.
# This fixture uses only family, source/destination, protocol and port matches.
packet_target() {
	awk -v family="$1" -v source="$2" -v proto="$3" -v port="$4" '
	$1 == family && $2 == "-A" && $3 == "mwan3_rules" {
		matches=1; target=""
		for (i=4; i<=NF; i++) {
			if ($i == "-s" && $(i+1) != source) matches=0
			if ($i == "-d" && $(i+1) != (family == "ipv4" ? "0.0.0.0/0" : "::/0")) matches=0
			if ($i == "-p" && $(i+1) != proto && $(i+1) != "all") matches=0
			if ($i == "--dports" && $(i+1) != port) matches=0
			if ($i == "-j") target=$(i+1)
		}
		if (matches && target != "") { print target; exit }
	}' "$ROOT/compiled-rules"
}
for explicit_family in yes no; do
	if [ "$explicit_family" = no ]; then
		uci delete mwan3.old_v4.family
		uci delete mwan3.old_v6.family
		uci commit mwan3
	fi
	run
	compile_rules
	[ "$(packet_target ipv6 2001:db8::100/128 tcp 443)" = MARK ] || fail 'specific IPv6 policy was shadowed'
	[ "$(packet_target ipv6 2001:db8::200/128 tcp 443)" = mwan3_rule_xwan_https_v6 ] || fail 'IPv6 HTTPS misses balancing'
	[ "$(packet_target ipv4 192.0.2.100/32 tcp 443)" = mwan3_rule_xwan_https ] || fail 'IPv4 HTTPS misses balancing'
	[ "$(packet_target ipv4 192.0.2.100/32 udp 53)" = mwan3_policy_xwan_balanced ] || fail 'IPv4 default misses balancing'
	[ "$(packet_target ipv6 2001:db8::200/128 udp 53)" = mwan3_policy_xwan_balanced ] || fail 'IPv6 default misses balancing'
done
echo 'PASS: compiled packet matches preserve IPv6 exceptions across IPv4 defaults'

lua - "$MODEL" <<'EOF'
local selected = {}
local interfaces = {
	{ [".name"] = "wand", device = "lan4" },
	{ [".name"] = "wanc", ifname = "lan3" },
	{ [".name"] = "usbwan", device = "usb0" },
	{ [".name"] = "ponwan", device = "pon0" },
	{ [".name"] = "loopback" }, { [".name"] = "lan" },
	{ [".name"] = "wan6", proto = "dhcpv6" },
	{ [".name"] = "xwand01" }, -- Missing device.
	{ [".name"] = "xwan02", ifname = "mvlan02" }, -- Legacy.
	{ [".name"] = "custom", xwan = "1" },
	{ [".name"] = "renamed", device = "mvwanc01" },
	{ [".name"] = "old", ifname = "mvlan03" }
}
function translate(value) return value end
function Map()
	return {
		uci = { foreach = function(_, _, _, callback)
			for _, interface in ipairs(interfaces) do callback(interface) end
		end },
		section = function() return {
			option = function(_, _, name) return {
				value = function(_, value)
					if name == "interface" then selected[value] = true end
				end
			} end
		} end
	}
end
assert(loadfile(arg[1]))()
for _, name in ipairs({ "wand", "wanc", "usbwan", "ponwan" }) do
	assert(selected[name], "missing source " .. name)
	selected[name] = nil
end
assert(next(selected) == nil, "generated/non-source interface is selectable")
print("PASS: source selector excludes marked, legacy and missing-device generated interfaces")
EOF
echo 'PASS: all isolated xwan checks'

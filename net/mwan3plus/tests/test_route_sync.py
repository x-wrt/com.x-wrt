#!/usr/bin/env python3
"""Exercise production route synchronization with private routing tables.

No host network commands run. The ip fixture models route keys and failures;
the concurrency test holds the lifecycle lock while rebuilding a WAN table.
"""

import fcntl
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest


PACKAGE = Path(__file__).resolve().parents[1]
SHELL = os.environ.get("MWAN3_TEST_SHELL", "/bin/bash")
LAN = "192.168.16.0/24 dev br-lan proto kernel scope link src 192.168.16.1"
WAN = "192.168.0.0/24 dev eth0 proto static scope link metric 40"
DEFAULTS = ["default via 192.168.0.1 dev eth0 metric 40",
            "default via 192.168.99.1 dev eth5 metric 41"]

FIXTURE = r'''
config_load() {
	[ ! -e "$TEST_ROOT/fail-config" ] || return 1
	cfg_globals_enabled=$(cat "$TEST_ROOT/enabled")
}
config_get() { eval "$1=\${cfg_${2}_${3}:-\$4}"; }
config_get_bool() { config_get "$@"; }
config_foreach() {
	local callback=$1 section
	shift 2
	for section in wan xwan01 wan6; do "$callback" "$section" "$@"; done
}
cfg_wan_family=ipv4
cfg_xwan01_family=ipv4
cfg_wan6_family=ipv6
cfg_wan_enabled=1
cfg_xwan01_enabled=1
cfg_wan6_enabled=1
network_flush_cache() { :; }
network_get_device() {
	case "$2" in
		wan) export "$1=eth0";;
		xwan01) export "$1=eth5";;
		wan6) export "$1=eth6";;
		*) export "$1=";;
	esac
}
network_get_gateway() { export "$1=192.168.0.1"; }
network_get_metric() { export "$1=40"; }
mwan3_get_true_iface() { export "$1=$2"; }
mwan3_lock() { exec 9>"$TEST_ROOT/lifecycle.lock"; flock -x 9; }
mwan3_try_lock() {
	exec 9>"$TEST_ROOT/lifecycle.lock"
	flock -xn 9 && return 0
	exec 9>&-
	return 1
}
mwan3_unlock() { flock -u 9; exec 9>&-; }
mwan3_set_local_ipv4() { :; }
mwan3_set_connected_ipv4() { :; }
mwan3_set_local_ipv6() { :; }
mwan3_set_connected_ipv6() { :; }
LOG() { printf '%s\n' "$*" >> "$TEST_ROOT/log"; }
IP4="ip -4"
IP6="ip -6"
NEED_IPV4=1
NEED_IPV6=1
NO_IPV6=0
MWAN3_INTERFACE_MAX=60
'''

IP = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
root = Path(os.environ["TEST_ROOT"])
args = sys.argv[1:]
family = args.pop(0)
assert args.pop(0) == "route", args
action = args.pop(0)
with (root / "commands").open("a") as log:
    log.write(" ".join([family, action] + args) + "\n")
path = root / (family + ".json")
tables = json.loads(path.read_text())
table = "main"
if "table" in args:
    index = args.index("table")
    table = args.pop(index + 1)
    args.pop(index)
routes = tables.setdefault(table, [])
if action in ("list", "show"):
    if table == "all":
        for tid, entries in tables.items():
            for entry in entries:
                words = entry.split()
                words[1:1] = ["table", tid]
                print(" ".join(words))
    else:
        print("\n".join(routes))
    sys.exit(0)
if action == "flush":
    routes.clear()
else:
    route = " ".join(args)
    def key(value):
        words = value.split()
        def field(name):
            return words[words.index(name) + 1] if name in words else "0"
        return words[0], field("metric"), field("tos")
    matches = [old for old in routes if key(old) == key(route)]
    if (root / ("fail-" + action + "-" + table)).exists():
        sys.exit(2)
    if action == "add" and matches:
        sys.exit(2)
    if action == "del" and not matches:
        sys.exit(2)
    for old in matches:
        routes.remove(old)
    if action in ("add", "replace"):
        routes.append(route)
path.write_text(json.dumps(tables))
'''


class RouteSyncTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mwan3plus-routes-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for utility in ("awk", "cat", "flock", "grep", "python3", "sleep", "touch"):
            (self.bin / utility).symlink_to(shutil.which(utility))
        self.env = dict(os.environ, TEST_ROOT=str(self.root), PATH=str(self.bin))
        (self.bin / "ip").write_text(IP)
        (self.bin / "ip").chmod(0o755)
        (self.root / "enabled").write_text("1")
        # Source definitions only, replacing OpenWrt-only import files.
        library = (PACKAGE / "files/lib/mwan3/mwan3.sh").read_text()
        library = "\n".join(line for line in library.splitlines()
                            if not line.startswith(". /"))
        monitor = (PACKAGE / "files/usr/sbin/mwan3rtmon").read_text()
        monitor = monitor.rsplit('\nmain "$@"', 1)[0]
        monitor = "\n".join(line for line in monitor.splitlines()
                            if not line.startswith(". /"))
        self.script = self.root / "functions.sh"
        self.script.write_text(library + "\n" + monitor + "\n" + FIXTURE)
        self.tables({"main": [LAN, WAN], "1": [DEFAULTS[0]], "2": [DEFAULTS[1]],
                     "3": ["default dev eth6 metric 42"]})
        self.tables({"main": [], "3": ["default dev eth6 metric 42"]}, "-6")
        self.processes = []
        self.addCleanup(self.stop_processes)

    def stop_processes(self):
        for process in self.processes:
            if process.poll() is None:
                process.kill()
            process.communicate(timeout=5)

    def tables(self, value=None, family="-4"):
        path = self.root / (family + ".json")
        if value is not None:
            path.write_text(json.dumps(value))
        return json.loads(path.read_text())

    def spawn(self, code):
        process = subprocess.Popen(
            [SHELL, "-c", ". " + shlex.quote(str(self.script)) + "\n" + code],
            env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.processes.append(process)
        return process

    def run_shell(self, code):
        process = self.spawn(code)
        stdout, stderr = process.communicate(timeout=10)
        self.assertEqual(process.returncode, 0, stdout + stderr)
        return stdout

    def event(self, line, family="ipv4"):
        self.run_shell("mwan3_rtmon_update " + shlex.quote(line) + " " + family)

    def test_startup_repairs_missing_lan_routes_without_touching_other_family(self):
        self.event("")
        tables = self.tables()
        for tid in ("1", "2"):
            self.assertIn(LAN + " metric 256", tables[tid])
            self.assertIn(DEFAULTS[int(tid) - 1], tables[tid])
        self.assertEqual(tables["3"], ["default dev eth6 metric 42"])
        self.assertIn(WAN.removesuffix(" metric 40"), tables["1"])
        self.assertIn(WAN, tables["2"])
        self.event("")
        self.assertEqual(self.tables(), tables)

    def test_link_route_delete_and_readd_use_snapshot_metric(self):
        self.event("")
        self.event("Deleted " + WAN)
        self.assertEqual(self.tables()["1"], [DEFAULTS[0], LAN + " metric 256"])
        self.assertEqual(self.tables()["2"], [DEFAULTS[1], LAN + " metric 256"])
        self.event(WAN)
        for tid in ("1", "2"):
            self.assertEqual(len(self.tables()[tid]), 3)

    def test_carrier_only_recovery_copies_routes_excluded_at_boot(self):
        tables = self.tables()
        tables["main"] = [LAN + " linkdown", WAN]
        self.tables(tables)
        self.event("")
        for tid in ("1", "2"):
            self.assertFalse(any(route.startswith("192.168.16.0/24 ")
                                 for route in self.tables()[tid]))
        # Carrier recovery changes the flag without an RTM_NEWROUTE event.
        tables = self.tables()
        tables["main"] = [LAN, WAN]
        self.tables(tables)
        self.event("[LINK]5: br-lan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP")
        for tid in ("1", "2"):
            self.assertIn(LAN + " metric 256", self.tables()[tid])

    def test_link_down_and_deleted_events_do_not_reconcile(self):
        before = self.tables()
        for line in (
            "[LINK]5: br-lan: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 state DOWN",
            "[LINK]5: br-lan: <BROADCAST,MULTICAST> mtu 1500 state DOWN",
            "[LINK]Deleted 5: br-lan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500",
        ):
            self.event(line)
            self.assertEqual(self.tables(), before)

    def test_carrier_recovery_does_not_activate_an_offline_wan_table(self):
        tables = self.tables()
        tables["2"] = []
        self.tables(tables)
        self.event("[LINK]5: br-lan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP")
        self.assertIn(LAN + " metric 256", self.tables()["1"])
        self.assertEqual(self.tables()["2"], [])

    def test_labelled_route_events_keep_add_delete_behavior(self):
        self.event("[ROUTE]" + LAN)
        for tid in ("1", "2"):
            self.assertIn(LAN + " metric 256", self.tables()[tid])
        self.event("[ROUTE]Deleted " + LAN)
        for tid in ("1", "2"):
            self.assertNotIn(LAN + " metric 256", self.tables()[tid])

    def test_replaced_gateway_updates_each_table_without_deleting_other_routes(self):
        old = "172.16.0.0/16 via 192.168.99.1 dev eth5 proto static metric 41"
        new = old.replace("192.168.99.1", "192.168.99.2")
        self.event(old)
        self.event(new)
        for tid in ("1", "2"):
            self.assertNotIn(old, self.tables()[tid])
            self.assertIn(new, self.tables()[tid])
        self.assertNotIn(" del ", (self.root / "commands").read_text())

    def test_failed_update_preserves_other_tables_and_old_route(self):
        old = LAN + " metric 256"
        new = LAN.replace("192.168.16.1", "192.168.16.2")
        tables = self.tables()
        tables["1"].append(old)
        tables["2"].append(old)
        self.tables(tables)
        (self.root / "fail-replace-1").touch()
        self.event(new)
        self.assertIn(old, self.tables()["1"])
        self.assertIn(new + " metric 256", self.tables()["2"])
        self.assertNotIn(" del ", (self.root / "commands").read_text())

    def test_route_event_waits_for_hotplug_table_rebuild(self):
        self.run_shell('mwan3_lock hotplug wan; ip -4 route flush table 1; mwan3_unlock')
        lifecycle = self.spawn('''
mwan3_lock hotplug wan
touch "$TEST_ROOT/rebuilding"
while [ ! -e "$TEST_ROOT/continue" ]; do sleep 0.02; done
ip -4 route add table 1 default via 192.168.0.1 dev eth0 metric 40
mwan3_unlock
''')
        deadline = time.monotonic() + 5
        while not (self.root / "rebuilding").exists():
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.02)
        monitor = self.spawn("mwan3_rtmon_update " + shlex.quote(LAN) + " ipv4")
        time.sleep(0.1)
        self.assertIsNone(monitor.poll(), "route update bypassed the hotplug lock")
        (self.root / "continue").touch()
        for process in (lifecycle, monitor):
            output = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, output)
        self.assertIn(LAN + " metric 256", self.tables()["1"])

    def test_stopped_service_and_config_failure_leave_tables_unchanged(self):
        before = self.tables()
        (self.root / "enabled").write_text("0")
        self.event(LAN)
        self.assertEqual(self.tables(), before)
        (self.root / "fail-config").touch()
        self.run_shell("mwan3_rtmon_update '' ipv4; test $? = 1")
        self.run_shell('mwan3_lock check lock; mwan3_unlock')
        self.assertEqual(self.tables(), before)

    def test_monitor_can_stop_while_lifecycle_lock_is_held(self):
        with (self.root / "lifecycle.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            monitor = self.spawn("mwan3_rtmon_update " + shlex.quote(LAN) + " ipv4")
            time.sleep(0.1)
            self.assertIsNone(monitor.poll())
            monitor.terminate()
            # A blocking lock child would keep these pipes open until the
            # lifecycle lock is released. Nonblocking retries leave no waiter.
            monitor.communicate(timeout=3)
            self.assertEqual(self.tables()["1"], [DEFAULTS[0]])
        self.run_shell('mwan3_try_lock && mwan3_unlock')

    def test_ipv6_expiry_and_attributes_survive_snapshot_and_delete(self):
        route = "2001:db8:1::/64 dev eth6 proto kernel scope link metric 42 expires 500sec pref medium"
        self.tables({"main": [route], "3": ["default dev eth6 metric 42"]}, "-6")
        self.event("", "ipv6")
        expected = "2001:db8:1::/64 dev eth6 proto kernel scope link pref medium"
        self.assertIn(expected, self.tables(family="-6")["3"])
        self.event("Deleted " + route, "ipv6")
        self.assertEqual(self.tables(family="-6")["3"], ["default dev eth6 metric 42"])

    def test_hotplug_snapshot_keeps_one_metric_for_own_wan(self):
        self.run_shell("mwan3_add_non_default_iface_route wan eth0 ipv4")
        self.event(WAN)
        own_routes = [route for route in self.tables()["1"] if route.startswith("192.168.0.0/24 ")]
        self.assertEqual(own_routes, [WAN.removesuffix(" metric 40")])


if __name__ == "__main__":
    unittest.main()

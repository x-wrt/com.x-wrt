#!/usr/bin/env python3
"""Run the firewall lifecycle scripts with isolated UCI/network command fixtures.

No host firewall commands are executed. MWAN3_TEST_SHELL may select BusyBox ash;
the default is Bash because the existing OpenWrt libraries use export -n/read -d.
"""

import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest


PACKAGE = Path(__file__).resolve().parents[1]
SHELL = os.environ.get("MWAN3_TEST_SHELL", "/bin/bash")


FIXTURE = r'''
event() { printf '%s\n' "$*" >> "$TEST_ROOT/events"; }
config_load() {
	[ ! -e "$TEST_ROOT/fail-load" ] || return 1
	. "$TEST_ROOT/config"
	cfg_globals_enabled=$(cat "$TEST_ROOT/enabled")
}
config_get() { eval "$1=\${cfg_${2}_${3}:-\$4}"; }
config_get_bool() { config_get "$@"; }
config_foreach() {
	local callback="$1" section
	for section in $test_interfaces; do "$callback" "$section"; done
}
uci_toggle_state() {
	event "state $3 $4"
	printf '%s\n' "$4" > "$TEST_ROOT/state_$3"
	[ "$3" != enabled ] || printf '%s\n' "$4" > "$TEST_ROOT/enabled"
}
uci_get_state() { cat "$TEST_ROOT/state_$3" 2>/dev/null; }
mwan3_lock() {
	[ "${test_lock_held:-0}" = 0 ] || exit 88
	exec 9>"$TEST_ROOT/command.lock"
	flock -x 9
	test_lock_held=1
	event locked
}
mwan3_unlock() {
	[ "$test_lock_held" = 1 ] || exit 89
	event unlocked
	test_lock_held=0
	flock -u 9
	exec 9>&-
}
mwan3_set_local_ipset() { event local-ipset; }
mwan3_set_connected_ipset() { event connected-ipset; }
mwan3_set_general_rules() { event ip-rules; }
mwan3_set_general_iptables() {
	event restore
	if [ -e "$TEST_ROOT/pause-restore" ]; then
		touch "$TEST_ROOT/restoring"
		while [ -e "$TEST_ROOT/pause-restore" ]; do sleep 0.02; done
	fi
	[ ! -e "$TEST_ROOT/fail-restore" ] || return 1
	[ "$NEED_IPV4" = 0 ] || touch "$TEST_ROOT/ipv4.hook" "$TEST_ROOT/ipv4.prerouting" "$TEST_ROOT/ipv4.output"
	[ "$NEED_IPV6" = 0 ] || touch "$TEST_ROOT/ipv6.hook" "$TEST_ROOT/ipv6.prerouting" "$TEST_ROOT/ipv6.output"
}
ifup() { event "ifup $1"; }
mwan3_track_clean() { event "track-clean $1"; }
mwan3_add_all_nondefault_routes() { event routes; }
mwan3_set_ipv6_native() { event native-v6; }
mwan3_set_policies_iptables() { event policies; }
mwan3_set_user_rules() { event user-rules; }
mwan3_ipv6_masq_cleanup() { event nat6-clean; }
mwan3_rtmon() { event rtmon; }
'''


IPTABLES = r'''#!/bin/sh
family=ipv4
case "$0" in *ip6tables*) family=ipv6;; esac
printf 'check %s %s\n' "$family" "$*" >> "$TEST_ROOT/events"
case " $* " in
	*" -t nat "*)
		# Model xtables contention: every NAT operation must wait for its lock.
		case " $* " in *" -w "*) :;; *) exit 4;; esac
		while [ "$#" -gt 0 ]; do
			case "$1" in
				-S) [ ! -f "$TEST_ROOT/nat66.rules" ] || cat "$TEST_ROOT/nat66.rules"; exit 0;;
				-A) shift; printf '%s\n' "-A $*" >> "$TEST_ROOT/nat66.rules"; exit 0;;
				-D)
					shift
					awk -v rule="-A $*" '$0 != rule' "$TEST_ROOT/nat66.rules" > "$TEST_ROOT/nat66.tmp"
					mv "$TEST_ROOT/nat66.tmp" "$TEST_ROOT/nat66.rules"
					exit 0;;
			esac
			shift
		done
		exit 2;;
esac
while [ "$#" -gt 0 ]; do
	case "$1" in
		-S) [ "${2:-}" != mwan3_hook ] || test -e "$TEST_ROOT/$family.hook"; exit $?;;
		-C)
			case "$2" in PREROUTING) target=prerouting;; OUTPUT) target=output;; *) exit 2;; esac
			test -e "$TEST_ROOT/$family.$target"; exit $?;;
	esac
	shift
done
exit 2
'''


UCI = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
root = Path(os.environ["TEST_ROOT"])
args = [arg for arg in sys.argv[1:] if arg != "-q"]
cmd, key = args
saved = root / "firewall.json"
pending = root / "pending.json"
state = json.loads(saved.read_text())
delta = json.loads(pending.read_text()) if pending.exists() else {}
state.update(delta)
state = {key: value for key, value in state.items() if value is not None}
if (root / ("fail-" + cmd)).exists():
    sys.exit(1)
if cmd == "get":
    if key not in state:
        sys.exit(1)
    print(state[key])
elif cmd in ("set", "delete"):
    with (root / "uci-events").open("a") as log:
        log.write(cmd + " " + key + "\n")
    if cmd == "set":
        key, value = key.split("=", 1)
        delta[key] = value
    else:
        for entry in state:
            if entry == key or entry.startswith(key + "."):
                delta[entry] = None
    pending.write_text(json.dumps(delta))
elif cmd == "changes":
    for key, value in delta.items():
        print("-" + key if value is None else key + "='" + value + "'")
elif cmd == "commit":
    with (root / "uci-events").open("a") as log:
        log.write("commit " + key + "\n")
    saved.write_text(json.dumps(state, sort_keys=True))
    pending.unlink(missing_ok=True)
else:
    sys.exit(2)
'''


class FirewallReloadTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mwan3plus-firewall-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        # Keep real firewall/network commands outside PATH, even on hosts that
        # have ip6tables or fw4 installed.
        for utility in ("awk", "cat", "flock", "grep", "mkdir", "mv", "python3", "rm", "sleep", "touch", "tr"):
            (self.bin / utility).symlink_to(shutil.which(utility))
        self.env = dict(os.environ, TEST_ROOT=str(self.root), PATH=str(self.bin))
        self.processes = []
        self.addCleanup(self.stop_processes)
        for directory in ("lib/mwan3", "usr/sbin", "var/run", "usr/share/libubox"):
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        (self.root / "lib/functions.sh").write_text("")
        (self.root / "lib/functions").mkdir()
        (self.root / "lib/functions/network.sh").write_text("")
        (self.root / "usr/share/libubox/jshn.sh").write_text("")
        for name in ("common.sh", "mwan3.sh"):
            self.copy_script("lib/mwan3/" + name)
        self.write("fixture.sh", FIXTURE)
        self.cli = self.copy_script("usr/sbin/mwan3", inject=True)
        self.copy_script("usr/share/mwan3/mwan3-reload.sh")
        self.write("bin/iptables", IPTABLES, executable=True)
        self.write("bin/ip6tables", IPTABLES, executable=True)
        self.write("bin/ip", "#!/bin/sh\nexit 0\n", executable=True)
        self.write("bin/ipset", "#!/bin/sh\nexit 0\n", executable=True)
        self.write("bin/pgrep", "#!/bin/sh\nexit 1\n", executable=True)
        self.write("bin/logger", '#!/bin/sh\nprintf "%s\\n" "$*" >> "$TEST_ROOT/events"\n', executable=True)
        self.write("bin/uci", UCI, executable=True)
        self.write("bin/iptables-restore", '#!/bin/sh\ncat >/dev/null\nrm -f "$TEST_ROOT"/ipv4.*\n', executable=True)
        self.write("bin/ip6tables-restore", '#!/bin/sh\ncat >/dev/null\nrm -f "$TEST_ROOT"/ipv6.*\n', executable=True)
        self.configure()
        self.write("firewall.json", json.dumps({"firewall.other": "include", "firewall.other.path": "/keep"}))

    def stop_processes(self):
        for process in self.processes:
            if process.poll() is None:
                process.kill()
            process.communicate(timeout=5)

    def write(self, name, content, executable=False):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        if executable:
            path.chmod(0o755)
        return path

    def copy_script(self, relative, inject=False):
        source = (PACKAGE / "files" / relative).read_text()
        for prefix in ("/lib/", "/usr/", "/var/run/"):
            source = source.replace(prefix, str(self.root) + prefix)
        if inject:
            source = source.replace('\ncase "$1" in\n', '\n. "$TEST_ROOT/fixture.sh"\n\ncase "$1" in\n')
        # The include runs the CLI directly, so choose the same test interpreter.
        source = source.replace("#!/bin/sh\n", "#!" + SHELL + "\n", 1)
        return self.write(relative, source, executable=True)

    def configure(self, families=("any",), enabled=1, mask="0x3F00"):
        self.write("enabled", str(enabled))
        lines = [f"cfg_globals_mmx_mask={mask}", "test_interfaces='" + " ".join(f"wan{i}" for i in range(len(families))) + "'"]
        for index, family in enumerate(families):
            lines.extend((f"cfg_wan{index}_enabled=1", f"cfg_wan{index}_family={family}"))
        self.write("config", "\n".join(lines) + "\n")

    def hooks(self, *families):
        for family in families:
            for name in ("hook", "prerouting", "output"):
                self.write(f"{family}.{name}", "")

    def events(self, name="events"):
        path = self.root / name
        return path.read_text().splitlines() if path.exists() else []

    def run_cli(self, command="firewall-reload", expected=0):
        result = subprocess.run([SHELL, str(self.cli), command], env=self.env,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, expected, result.stderr)
        return result

    def spawn_cli(self, command="firewall-reload"):
        process = subprocess.Popen([SHELL, str(self.cli), command], env=self.env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.processes.append(process)
        return process

    def wait_for(self, name):
        deadline = time.monotonic() + 5
        while not (self.root / name).exists():
            self.assertLess(time.monotonic(), deadline, f"timeout waiting for {name}")
            time.sleep(0.02)

    def test_full_flush_restores_once_and_reload_is_unchanged(self):
        self.run_cli()
        events = self.events()
        for stage in ("restore", "policies", "user-rules", "native-v6", "nat6-clean", "rtmon"):
            self.assertEqual(events.count(stage), 1)
        self.assertEqual(events.count("locked"), 1)
        self.assertEqual(events.count("unlocked"), 1)
        self.run_cli()
        self.assertEqual(self.events().count("restore"), 1)
        self.assertFalse((self.root / "uci-events").exists())
        for family in ("ipv4", "ipv6"):
            for name in ("hook", "prerouting", "output"):
                (self.root / f"{family}.{name}").unlink()
        self.run_cli()
        self.assertEqual(self.events().count("restore"), 2)

    def test_manual_start_restart_and_stop_keep_lifecycle(self):
        self.configure(enabled=0)
        self.run_cli("start")
        self.run_cli("restart")
        self.assertEqual(self.events().count("restore"), 2)
        self.assertEqual((self.root / "enabled").read_text().strip(), "1")
        self.run_cli("stop")
        self.assertEqual((self.root / "enabled").read_text().strip(), "0")
        self.assertEqual(self.events().count("locked"), 4)
        self.assertEqual(self.events().count("unlocked"), 4)

    def test_disabled_and_not_started_do_not_initialize(self):
        self.configure(enabled=0)
        self.run_cli()
        self.assertFalse((self.root / "var/run/mwan3").exists())
        self.assertFalse(any(event.startswith("state ") for event in self.events()))
        self.assertNotIn("restore", self.events())

    def test_only_needed_families_are_checked(self):
        for family in ("ipv4", "ipv6"):
            with self.subTest(family=family):
                self.configure((family,))
                self.hooks(family)
                self.write("events", "")
                self.run_cli()
                self.assertNotIn("restore", self.events())
                other = "ipv6" if family == "ipv4" else "ipv4"
                self.assertFalse(any(event.startswith(f"check {other} ") for event in self.events()))

    def test_missing_ipv6_binary_and_no_enabled_interfaces(self):
        (self.bin / "ip6tables").unlink()
        self.hooks("ipv4")
        self.run_cli()
        self.assertNotIn("restore", self.events())
        self.configure(())
        (self.root / "ipv4.hook").unlink()
        self.run_cli()
        self.assertNotIn("restore", self.events())

    def test_interfaces_beyond_mask_capacity_are_ignored(self):
        self.configure(("ipv4", "ipv4", "ipv4", "ipv4", "ipv6"), mask="0x0700")
        self.hooks("ipv4")
        self.run_cli()
        self.assertNotIn("restore", self.events())

    def test_missing_parent_jump_triggers_recovery(self):
        self.hooks("ipv4", "ipv6")
        (self.root / "ipv6.output").unlink()
        self.run_cli()
        self.assertIn("restore", self.events())

    def test_concurrent_callbacks_recheck_after_recovery(self):
        self.write("pause-restore", "")
        processes = [self.spawn_cli()]
        self.wait_for("restoring")
        processes.extend(self.spawn_cli() for _ in range(5))
        (self.root / "pause-restore").unlink()
        for process in processes:
            _, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, stderr)
        self.assertEqual(self.events().count("restore"), 1)

    def test_stop_is_serialized_and_later_callback_stays_disabled(self):
        self.write("pause-restore", "")
        recovery = self.spawn_cli()
        self.wait_for("restoring")
        stop = self.spawn_cli("stop")
        self.wait_for("var/run/mwan3.init")
        (self.root / "pause-restore").unlink()
        for process in (recovery, stop):
            _, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, stderr)
        self.run_cli()
        self.assertEqual((self.root / "enabled").read_text().strip(), "0")
        self.assertEqual(self.events().count("restore"), 1)
        self.assertFalse((self.root / "var/run/mwan3").exists())

    def test_recovery_failure_unlocks_and_can_retry(self):
        self.write("fail-restore", "")
        self.run_cli(expected=1)
        self.assertIn("unlocked", self.events())
        (self.root / "fail-restore").unlink()
        self.run_cli()
        self.assertEqual(self.events().count("restore"), 2)

    def test_config_failure_unlocks_without_start(self):
        self.write("fail-load", "")
        self.run_cli(expected=1)
        self.assertEqual(self.events(), ["locked", "unlocked"])

    def test_production_nat66_helper_rebuilds_without_duplicates_and_waits(self):
        self.configure(("ipv6",))
        setup = '\n'.join((
            '. "$TEST_ROOT/lib/mwan3/common.sh"',
            '. "$TEST_ROOT/lib/mwan3/mwan3.sh"',
            '. "$TEST_ROOT/fixture.sh"',
            'config_load mwan3',
            'INTERFACE=wan0 DEVICE=eth1 MWAN3_STARTUP=1',
        ))

        def run_helper(action):
            result = subprocess.run([SHELL, "-c", setup + '\nACTION=' + action + '\nmwan3_ipv6_masq_help'],
                                    env=self.env, capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)

        run_helper("ifup")
        rules = (self.root / "nat66.rules").read_text()
        self.assertIn("! --match-set mwan3_wan0_ipv6_src_from src", rules)
        self.assertIn("masq-help-wan0-dev -j MASQUERADE", rules)
        run_helper("ifup")
        self.assertEqual((self.root / "nat66.rules").read_text(), rules)
        # A full firewall flush removes POSTROUTING helpers as well as mangle.
        self.write("nat66.rules", "")
        run_helper("ifup")
        self.assertEqual((self.root / "nat66.rules").read_text(), rules)
        run_helper("ifdown")
        self.assertEqual((self.root / "nat66.rules").read_text(), "")

    def test_source_and_direct_include_return_without_lock_wait(self):
        include = self.root / "usr/share/mwan3/mwan3-reload.sh"
        with (self.root / "command.lock").open("w") as lockfile:
            import fcntl
            fcntl.flock(lockfile, fcntl.LOCK_EX)
            for sourced in (True, False):
                command = ('config() { exit 99; }; . ' + shlex.quote(str(include))) if sourced else shlex.quote(str(include))
                result = subprocess.run([SHELL, "-c", command], env=self.env,
                                        capture_output=True, timeout=2)
                self.assertEqual(result.returncode, 0)
            fcntl.flock(lockfile, fcntl.LOCK_UN)
        self.wait_for("events")
        deadline = time.monotonic() + 5
        while self.events().count("unlocked") < 2:
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.02)
        self.assertEqual(self.events().count("restore"), 1)

    def migration(self, expected=0):
        result = subprocess.run([SHELL, str(PACKAGE / "files/etc/uci-defaults/mwan3-reload-firewall")],
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, expected, result.stderr)
        return json.loads((self.root / "firewall.json").read_text())

    def test_fw3_migration_preserves_others_and_does_not_write_twice(self):
        state = json.loads((self.root / "firewall.json").read_text())
        state.update({"firewall.mwan3_ipv6_masq": "include", "firewall.mwan3": "include",
                      "firewall.mwan3.reload": "1", "firewall.mwan3.fw4_compatible": "1"})
        self.write("firewall.json", json.dumps(state))
        state = self.migration()
        self.assertEqual(state["firewall.other.path"], "/keep")
        self.assertEqual(state["firewall.mwan3"], "include")
        self.assertEqual(state["firewall.mwan3.path"], "/usr/share/mwan3/mwan3-reload.sh")
        self.assertEqual(state["firewall.mwan3.reload"], "0")
        self.assertNotIn("firewall.mwan3.fw4_compatible", state)
        self.assertNotIn("firewall.mwan3_ipv6_masq", state)
        saved = self.root / "firewall.json"
        before = (saved.read_bytes(), saved.stat(), self.events("uci-events"))
        self.migration()
        self.assertEqual(saved.read_bytes(), before[0])
        self.assertEqual((saved.stat().st_mtime_ns, saved.stat().st_ino), (before[1].st_mtime_ns, before[1].st_ino))
        self.assertEqual(self.events("uci-events"), before[2])

    def test_fw4_registration_and_return_to_fw3(self):
        self.migration()
        self.write("bin/fw4", "#!/bin/sh\nexit 0\n", executable=True)
        state = self.migration()
        self.assertEqual(state["firewall.mwan3.fw4_compatible"], "1")
        self.assertNotIn("firewall.mwan3.reload", state)
        saved = self.root / "firewall.json"
        before = (saved.read_bytes(), saved.stat(), self.events("uci-events"))
        self.migration()
        self.assertEqual(saved.read_bytes(), before[0])
        self.assertEqual((saved.stat().st_mtime_ns, saved.stat().st_ino), (before[1].st_mtime_ns, before[1].st_ino))
        self.assertEqual(self.events("uci-events"), before[2])
        (self.bin / "fw4").unlink()
        state = self.migration()
        self.assertNotIn("firewall.mwan3.fw4_compatible", state)
        self.assertEqual(state["firewall.mwan3.reload"], "0")

    @unittest.skipUnless(os.environ.get("MWAN3_TEST_FW4_SOURCE") and os.environ.get("MWAN3_TEST_UCODE"),
                         "set MWAN3_TEST_FW4_SOURCE and MWAN3_TEST_UCODE for the real fw4 include runner")
    def test_real_fw4_parser_and_include_runner(self):
        fw4_source = Path(os.environ["MWAN3_TEST_FW4_SOURCE"]).resolve()
        ucode = str(Path(os.environ["MWAN3_TEST_UCODE"]).resolve())
        # Use fw4's own dependency mocks; all executed network commands still
        # resolve exclusively to this test's private command fixtures.
        (self.bin / "sh").symlink_to(SHELL)
        self.write("bin/fw4", "#!/bin/sh\nexit 0\n", executable=True)
        state = self.migration()
        registration = {key.removeprefix("firewall.mwan3."): value
                        for key, value in state.items() if key.startswith("firewall.mwan3.")}
        registration[".name"] = "mwan3"
        registration[".type"] = "include"
        registration["path"] = str(self.root / "usr/share/mwan3/mwan3-reload.sh")
        fixture = "fs/open~" + re.sub(r"[^A-Za-z0-9_-]+", "_", registration["path"]) + ".txt"
        self.write(fixture, "# reachable include\n")
        runner = self.write("fw4-includes.uc", '''{%
let native_system = system;
require("mocklib");
let fw4 = require("fw4");
fw4.state = {};
fw4.parse_include(MWAN3_INCLUDE);
if (length(fw4.state.includes) != 1)
    die("mwan3 script include was not accepted");
fw4.read_state = () => fw4.state;
include(FW4_MAIN, {
    getenv: name => name == "ACTION" ? "includes" : null,
    system: native_system
});
%}
''')
        command = [ucode, "-S", "-T,", "-L", str(fw4_source / "tests/lib"),
                   "-L", str(fw4_source / "root/usr/share/ucode"),
                   "-D", "MOCK_SEARCH_PATH=" + json.dumps([str(self.root)]),
                   "-D", "MWAN3_INCLUDE=" + json.dumps(registration),
                   "-D", "FW4_MAIN=" + json.dumps(str(fw4_source / "root/usr/share/firewall4/main.uc")),
                   str(runner)]
        self.hooks("ipv4", "ipv6")
        for callback, expected_restores in enumerate((0, 1, 1), start=1):
            if callback == 2:
                # Model fw4 flush (all tables), followed by firewall start.
                for family in ("ipv4", "ipv6"):
                    for name in ("hook", "prerouting", "output"):
                        (self.root / f"{family}.{name}").unlink()
            result = subprocess.run(command, env=self.env, capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, "")
            deadline = time.monotonic() + 5
            while self.events().count("unlocked") < callback:
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.02)
            self.assertEqual(self.events().count("restore"), expected_restores)

    def test_migration_failed_commit_is_retried(self):
        original = (self.root / "firewall.json").read_bytes()
        self.write("fail-commit", "")
        self.migration(expected=1)
        self.assertEqual((self.root / "firewall.json").read_bytes(), original)
        (self.root / "fail-commit").unlink()
        self.assertIn("firewall.mwan3", self.migration())
        self.assertEqual(self.events("uci-events").count("commit firewall"), 1)

    def test_migration_set_and_changes_errors_are_reported(self):
        for command in ("set", "changes"):
            with self.subTest(command=command):
                self.write("fail-" + command, "")
                self.migration(expected=1)
                (self.root / ("fail-" + command)).unlink()
        self.assertIn("firewall.mwan3", self.migration())

    def test_migration_delete_error_is_reported(self):
        self.write("firewall.json", json.dumps({"firewall.mwan3_ipv6_masq": "include"}))
        self.write("fail-delete", "")
        self.migration(expected=1)
        (self.root / "fail-delete").unlink()
        self.assertNotIn("firewall.mwan3_ipv6_masq", self.migration())


if __name__ == "__main__":
    if not shutil.which("flock"):
        raise SystemExit("flock is required for the isolated concurrency tests")
    unittest.main()

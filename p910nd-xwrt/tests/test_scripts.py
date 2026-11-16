#!/usr/bin/env python3
"""Native tests; set UCI, PROCD_SH, JSHN_SH and put native jshn on PATH."""

import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest


PACKAGE = Path(__file__).resolve().parent.parent
HOTPLUG = Path(os.environ.get("P910ND_HOTPLUG", PACKAGE / "files/p910nd.hotplug"))
INIT = Path(os.environ.get("P910ND_INIT", PACKAGE / "files/p910nd.init"))
UCI = shutil.which(os.environ.get("UCI", "uci"))
PROCD_SH = Path(os.environ.get("PROCD_SH", "/lib/functions/procd.sh"))
JSHN_SH = Path(os.environ.get("JSHN_SH", "/usr/share/libubox/jshn.sh"))


@unittest.skipUnless(UCI, "set UCI to a native uci executable")
class ScriptTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="p910nd-scripts-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / "config"
        self.delta = self.root / "delta"
        self.config.mkdir()
        self.delta.mkdir()
        (self.config / "p910nd").touch()
        self.uci_cmd = [UCI, "-c", str(self.config), "-t", str(self.delta)]
        self.prelude = "uci() { " + shlex.join(self.uci_cmd) + ' "$@"; }\n'

    def uci(self, *args):
        return subprocess.check_output(self.uci_cmd + list(args), text=True).strip()

    def section(self, name, device=None, **options):
        self.uci("set", "p910nd.{}=p910nd".format(name))
        if device is not None:
            options["device"] = device
        for key, value in options.items():
            self.uci("set", "p910nd.{}.{}={}".format(name, key, value))

    def shell(self, script, expected_returncode=0):
        result = subprocess.run(
            ["busybox", "ash"], input=self.prelude + script,
            text=True, capture_output=True, timeout=10, cwd=self.root,
        )
        self.assertEqual(result.returncode, expected_returncode, result.stderr)
        return result

    def hotplug(self, info="MFG:Acme;MDL:Printer;", devname="usb/lp0",
                expected_returncode=0):
        source = HOTPLUG.read_text()
        functions = source[source.index("match_current_device() {"):
                           source.index("send_driver() {")]
        values = dict(
            DAEMON="p910nd", UCI_DEV_CFG_NUMBER="-1", DEVNAME=devname,
            ieee1284info=info, BIDIR="1", THIS_USB_VIDPID="1234/5678",
            DRIVER_HOME=str(self.root / "drivers"),
            DRIVER_BLOBNAME_TAIL="1234_5678.bin", iSerialNumber="serial",
        )
        setup = "".join("{}={}\n".format(k, shlex.quote(v)) for k, v in values.items())
        self.shell(setup + functions
                   + '\nlogger() { printf "%s\\n" "$@" > logger.log; }\n'
                   + 'get_and_store_printer_info || exit $?\n'
                   + "printf '%s' \"$IFS\" > ifs\n", expected_returncode)

    def test_usb_metadata_is_not_executed(self):
        self.section("printer", "/dev/usb/lp0")
        marker = self.root / "executed"
        value = "Acme'$(touch {})'".format(marker)
        self.hotplug("MFG:{};MDL:Printer;".format(value))
        self.assertFalse(marker.exists(), "USB metadata executed a command")
        self.assertEqual(self.uci("get", "p910nd.printer.mdns_mfg"), value)

    def test_missing_device_does_not_shift_sections(self):
        self.section("empty")
        self.section("printer", "/dev/usb/lp0")
        self.hotplug()
        self.assertEqual(self.uci("get", "p910nd.printer.mdns_mfg"), "Acme")
        self.assertNotIn("p910nd.empty.mdns_mfg", self.uci("show", "p910nd"))

    def test_match_after_ten_sections(self):
        for index in range(13):
            self.section("printer{}".format(index), "/dev/usb/lp{}".format(index))
        self.hotplug(devname="usb/lp11")
        self.assertEqual(self.uci("get", "p910nd.printer11.mdns_mfg"), "Acme")
        self.assertNotIn("p910nd.printer0.mdns_mfg", self.uci("show", "p910nd"))
        self.assertNotIn("p910nd.printer12.mdns_mfg", self.uci("show", "p910nd"))

    def test_new_device_gets_its_own_section(self):
        self.section("existing", "/dev/usb/lp0", port="0", mdns_mfg="Existing")
        self.hotplug(devname="usb/lp1")
        self.assertEqual(self.uci("get", "p910nd.existing.device"), "/dev/usb/lp0")
        self.assertEqual(self.uci("get", "p910nd.@p910nd[1].device"), "/dev/usb/lp1")
        self.assertEqual(self.uci("get", "p910nd.@p910nd[1].mdns_mfg"), "Acme")
        self.assertEqual(self.uci("get", "p910nd.@p910nd[1].port"), "1")

    def test_new_device_uses_first_free_port(self):
        self.section("default", "/dev/usb/lp0")
        self.section("one", "/dev/usb/lp1", port="1")
        self.section("three", "/dev/usb/lp3", port="3", enabled="0")
        self.hotplug(devname="usb/lp2")
        self.assertEqual(self.uci("get", "p910nd.@p910nd[3].port"), "2")

    def test_existing_port_is_preserved(self):
        self.section("existing", "/dev/usb/lp0", port="7")
        self.hotplug()
        self.assertEqual(self.uci("get", "p910nd.existing.port"), "7")

    def test_missing_port_avoids_other_printers(self):
        self.section("existing", "/dev/usb/lp0", port="0")
        self.section("missing", "/dev/usb/lp1")
        self.hotplug(devname="usb/lp1")
        self.assertEqual(self.uci("get", "p910nd.missing.port"), "1")

    def test_no_free_port_does_not_add_conflicting_device(self):
        for port in range(10):
            self.section("printer{}".format(port), "/dev/usb/lp{}".format(port),
                         port=str(port))
        before = self.uci("show", "p910nd")
        self.hotplug(devname="usb/lp10", expected_returncode=1)
        self.assertEqual(self.uci("show", "p910nd"), before)
        self.assertIn("No free printer ports", (self.root / "logger.log").read_text())

    def test_metadata_keeps_colons_wildcards_and_ifs(self):
        self.section("printer", "/dev/usb/lp0", enabled="0", mdns="0")
        self.hotplug("MFG:Acme;MDL:Laser:*;COMMAND SET:PCL:XL;DES:O'Brien's printer")
        self.assertEqual(self.uci("get", "p910nd.printer.mdns_mdl"), "Laser:*")
        self.assertEqual(self.uci("get", "p910nd.printer.mdns_cmd"), "PCL:XL")
        self.assertEqual(self.uci("get", "p910nd.printer.mdns_ty"), "O'Brien's printer")
        self.assertEqual(self.uci("get", "p910nd.printer.enabled"), "0")
        self.assertEqual((self.root / "ifs").read_text(), " \t\n")

    def test_firmware_name_stays_inside_driver_directory(self):
        self.section("printer", "/dev/usb/lp0")
        self.hotplug("MFG:Acme/../../escape;MDL:Printer;", "usb/lp0")
        filename = Path(self.uci("get", "p910nd.printer.driver_file"))
        self.assertEqual(filename.parent, self.root / "drivers")

    def test_no_metadata_still_configures_device(self):
        self.hotplug("")
        self.assertEqual(self.uci("get", "p910nd.@p910nd[0].device"), "/dev/usb/lp0")
        self.assertEqual(self.uci("get", "p910nd.@p910nd[0].port"), "0")

    def test_hotplug_type_falls_back_to_model(self):
        self.hotplug("MFG:Acme;MDL:Laser Printer;")
        self.assertEqual(self.uci("get", "p910nd.@p910nd[0].mdns_ty"), "Laser Printer")

    def printer(self, name, **options):
        device = self.root / (name + " [1] with spaces")
        device.touch()
        self.section(name, str(device), enabled="1", **options)
        return device

    def service(self):
        if not (PROCD_SH.is_file() and JSHN_SH.is_file() and shutil.which("jshn")):
            self.skipTest("set PROCD_SH, JSHN_SH and put native jshn on PATH")
        library = self.root / "usr/share/libubox"
        library.mkdir(parents=True, exist_ok=True)
        target = library / "jshn.sh"
        if not target.exists():
            target.symlink_to(JSHN_SH.resolve())
        sections = re.findall(r"^p910nd\.([A-Za-z0-9_]+)=p910nd$",
                              self.uci("-X", "show", "p910nd"), re.MULTILINE)
        stubs = '''
config_get() {
	local result
	result=$(uci -q get "p910nd.$2.$3")
	export "$1=${result:-$4}"
}
config_get_bool() { config_get "$@"; }
config_load() { :; }
config_foreach() {
	local callback="$1" section
	shift 2
	for section in $test_sections; do "$callback" "$section" "$@"; done
}
flock() { :; }
uname() { printf '%s\\n' test-router; }
logger() { printf '%s\\n' "$@" >> logger.log; }
ubus() {
	[ "$1 $2 $3" = "call service set" ] || return 1
	printf '%s\\n' "$4" > service.json
}
'''
        setup = "IPKG_INSTROOT={}\ntest_sections={}\n".format(
            shlex.quote(str(self.root)), shlex.quote(" ".join(sections)))
        self.shell(setup + stubs + ". " + shlex.quote(str(PROCD_SH)) + "\n"
                   + INIT.read_text() + "\nprocd_open_service p910nd\n"
                   + "start_service\nprocd_close_service\n")
        return json.loads((self.root / "service.json").read_text())["instances"]

    def start(self, **options):
        device = self.printer("printer", **options)
        return device, self.service()["printer"]

    @staticmethod
    def mdns(instance, section):
        records = instance["data"]["mdns"]
        keys = [key for key in records if key.startswith("p910nd_" + section + "_")]
        assert len(keys) == 1, records
        return records[keys[0]]

    def test_init_preserves_arguments(self):
        device, instance = self.start(port="2", bind="fe80::1%br-lan", bidirectional="1")
        self.assertEqual(instance["command"], ["/usr/sbin/p910nd", "-d", "-b",
                                              "-f", str(device), "-i", "fe80::1%br-lan", "2"])

    def test_init_default_port_matches_mdns(self):
        _, instance = self.start(mdns="1", mdns_ty="Test printer")
        mdns = self.mdns(instance, "printer")
        self.assertEqual(instance["command"][-1], "0")
        self.assertEqual(mdns["service"], "_pdl-datastream._tcp.local")
        self.assertEqual(mdns["port"], 9100)
        self.assertEqual(mdns["instance"], "Test printer @ test-router (9100)")

    def test_same_model_printers_have_independent_announcements(self):
        for index in range(2):
            self.printer("printer" + str(index), port=str(index), mdns="1",
                         mdns_ty="Same Printer", mdns_sn="serial" + str(index))
        instances = self.service()
        names = []
        for index in range(2):
            name = "printer" + str(index)
            mdns = self.mdns(instances[name], name)
            names.append(mdns["instance"])
            self.assertEqual(mdns["port"], 9100 + index)
            self.assertIn("usb_SN=serial" + str(index), mdns["txt"])
        self.assertEqual(len(set(names)), 2)
        self.assertEqual(self.service(), instances, "service IDs and names changed on restart")

    def test_custom_name_and_txt_remain_data(self):
        marker = self.root / "executed"
        custom = "Office'$(touch {})'".format(marker)
        _, instance = self.start(mdns="1", mdns_name=custom,
                                 mdns_mdl="Laser:XL", mdns_note="O'Brien's office",
                                 mdns_cmd="PCL:XL,PDF", mdns_mfg="Acme")
        mdns = self.mdns(instance, "printer")
        self.assertEqual(mdns["instance"], custom)
        self.assertIn("ty=Laser:XL", mdns["txt"])
        self.assertIn("note=O'Brien's office", mdns["txt"])
        self.assertIn("usb_CMD=PCL:XL,PDF", mdns["txt"])
        self.assertFalse(marker.exists())

    def test_duplicate_custom_names_fall_back_for_both_printers(self):
        for index, custom in enumerate(("Office printer", "OFFICE PRINTER")):
            self.printer("printer" + str(index), port=str(index), mdns="1",
                         mdns_ty="Laser", mdns_name=custom)
        instances = self.service()
        for index in range(2):
            name = "printer" + str(index)
            self.assertEqual(self.mdns(instances[name], name)["instance"],
                             "Laser @ test-router ({})".format(9100 + index))

    def test_custom_name_cannot_take_another_default_name(self):
        self.printer("one", port="0", mdns="1", mdns_ty="Laser",
                     mdns_name="Laser @ test-router (9101)")
        self.printer("two", port="1", mdns="1", mdns_ty="Laser")
        instances = self.service()
        self.assertEqual(self.mdns(instances["one"], "one")["instance"],
                         "Laser @ test-router (9100)")

    def test_invalid_and_long_names_fall_back_without_breaking_printing(self):
        device = self.printer("printer", port="0", mdns="1", mdns_ty="Laser")
        for custom in ("x" * 64, "打印机" * 8, "Line\nBreak", "Office.Printer", "Back\\slash"):
            with self.subTest(custom=custom):
                self.uci("set", "p910nd.printer.mdns_name=" + custom)
                instance = self.service()["printer"]
                self.assertIn(str(device), instance["command"])
                self.assertEqual(self.mdns(instance, "printer")["instance"],
                                 "Laser @ test-router (9100)")
        self.assertIn("Invalid or duplicate", (self.root / "logger.log").read_text())

    def test_utf8_name_uses_byte_limit(self):
        custom = "中" * 21
        _, instance = self.start(mdns="1", mdns_name=custom)
        self.assertEqual(self.mdns(instance, "printer")["instance"], custom)

    def test_long_default_model_preserves_unique_port_suffix(self):
        _, instance = self.start(mdns="1", mdns_ty="打印机" * 30)
        name = self.mdns(instance, "printer")["instance"]
        self.assertLessEqual(len(name.encode("utf-8")), 63)
        self.assertTrue(name.endswith("(9100)"))

    def test_rename_replaces_old_registration_without_changing_other_printers(self):
        self.printer("printer", port="0", mdns="1", mdns_ty="Laser")
        self.printer("other", port="2", mdns="1", mdns_ty="Other Printer")
        before = self.service()
        self.uci("set", "p910nd.printer.mdns_name=Office Printer")
        after = self.service()
        self.assertNotEqual(set(before["printer"]["data"]["mdns"]),
                            set(after["printer"]["data"]["mdns"]))
        self.assertEqual(after["other"], before["other"])

    def test_same_name_updates_do_not_withdraw_the_instance(self):
        self.printer("printer", port="0", mdns="1", mdns_name="Office Printer")
        before = self.service()["printer"]
        self.uci("set", "p910nd.printer.port=1")
        self.uci("set", "p910nd.printer.mdns_note=Upstairs")
        self.uci("set", "p910nd.printer.mdns_name=OFFICE PRINTER")
        after = self.service()["printer"]
        self.assertEqual(set(before["data"]["mdns"]), set(after["data"]["mdns"]))
        mdns = self.mdns(after, "printer")
        self.assertEqual(mdns["port"], 9101)
        self.assertIn("note=Upstairs", mdns["txt"])

    def test_disconnected_duplicate_does_not_rename_remaining_printer(self):
        first = self.printer("first", port="0", mdns="1", mdns_ty="Laser", mdns_name="Office")
        self.printer("second", port="1", mdns="1", mdns_ty="Laser", mdns_name="Office")
        before = self.service()
        first.unlink()
        self.assertEqual(self.service()["second"], before["second"])

    def test_unplug_and_disable_remove_only_the_selected_announcement(self):
        first = self.printer("first", port="0", mdns="1", mdns_ty="Laser")
        self.printer("second", port="1", mdns="1", mdns_ty="Laser")
        before = self.service()
        first.unlink()
        after = self.service()
        self.assertNotIn("first", after)
        self.assertEqual(after["second"], before["second"])
        first.touch()
        self.uci("set", "p910nd.first.mdns=0")
        after = self.service()
        self.assertNotIn("data", after["first"])
        self.assertEqual(after["second"], before["second"])

    def hotplug_event(self, action, devname="usb/lp0"):
        source = HOTPLUG.read_text().replace("/etc/init.d/$DAEMON", "p910nd_service")
        source = source.replace('SYSUPGRADE_CONF="/etc/sysupgrade.conf"',
                                "SYSUPGRADE_CONF=" + shlex.quote(str(self.root / "sysupgrade.conf")))
        setup = "ACTION={}\nDEVNAME={}\nDEVPATH=/devices/test/usb/1-1/1-1:1.0/usbmisc/lp0\n".format(
            shlex.quote(action), shlex.quote(devname))
        stubs = '''
logger() { :; }
p910nd_service() { printf '%s\\n' "$@" >> lifecycle; }
chmod() { :; }
chgrp() { :; }
cat() {
	case "$1" in
		/sys/*)
			printf '%s\\n' "$1" >> sysfs_reads
			case "$1" in
				*/bInterfaceClass) printf '07\\n';;
				*/bInterfaceSubClass) printf '01\\n';;
				*/bInterfaceProtocol) printf '02\\n';;
				*/idVendor) printf '1234\\n';;
				*/idProduct) printf '5678\\n';;
				*/ieee1284_id) printf 'MFG:Acme;MDL:Laser;\\n';;
			esac;;
		*) command cat "$@";;
	esac
}
'''
        return self.shell(setup + stubs + source)

    def test_remove_does_not_access_sysfs(self):
        result = self.hotplug_event("remove")
        self.assertEqual(result.stderr, "")
        self.assertFalse((self.root / "sysfs_reads").exists())
        self.assertEqual((self.root / "lifecycle").read_text(), "reload\n")

    def test_nonprinter_remove_does_not_reload(self):
        self.hotplug_event("remove", "other0")
        self.assertFalse((self.root / "lifecycle").exists())

    def test_add_reloads_without_restarting_other_printers(self):
        self.section("existing", "/dev/usb/lp0", port="0")
        self.uci("add", "p910nd", "hotplug")
        self.uci("set", "p910nd.@hotplug[0].driver_home=" + str(self.root / "drivers"))
        (self.root / "sysupgrade.conf").touch()
        self.hotplug_event("add")
        self.assertEqual((self.root / "lifecycle").read_text(), "reload\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)

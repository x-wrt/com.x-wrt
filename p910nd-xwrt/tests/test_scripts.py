#!/usr/bin/env python3
"""Run with UCI=/path/to/host/uci; all configuration lives in a temp directory."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest


PACKAGE = Path(__file__).resolve().parent.parent
HOTPLUG = Path(os.environ.get("P910ND_HOTPLUG", PACKAGE / "files/p910nd.hotplug"))
INIT = Path(os.environ.get("P910ND_INIT", PACKAGE / "files/p910nd.init"))
UCI = shutil.which(os.environ.get("UCI", "uci"))


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

    def shell(self, script):
        result = subprocess.run(
            ["busybox", "ash"], input=self.prelude + script,
            text=True, capture_output=True, timeout=10, cwd=self.root,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def hotplug(self, info="MFG:Acme;MDL:Printer;", devname="usb/lp0"):
        source = HOTPLUG.read_text()
        functions = source[source.index("match_current_device() {"):
                           source.index("daemon_restart() {")]
        values = dict(
            DAEMON="p910nd", UCI_DEV_CFG_NUMBER="-1", DEVNAME=devname,
            ieee1284info=info, BIDIR="1", THIS_USB_VIDPID="1234/5678",
            DRIVER_HOME=str(self.root / "drivers"),
            DRIVER_BLOBNAME_TAIL="1234_5678.bin", iSerialNumber="serial",
        )
        setup = "".join("{}={}\n".format(k, shlex.quote(v)) for k, v in values.items())
        self.shell(setup + functions + '\nget_and_store_printer_info\n'
                   + "printf '%s' \"$IFS\" > ifs\n")

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
        self.section("existing", "/dev/usb/lp0", mdns_mfg="Existing")
        self.hotplug(devname="usb/lp1")
        self.assertEqual(self.uci("get", "p910nd.existing.device"), "/dev/usb/lp0")
        self.assertEqual(self.uci("get", "p910nd.@p910nd[1].device"), "/dev/usb/lp1")
        self.assertEqual(self.uci("get", "p910nd.@p910nd[1].mdns_mfg"), "Acme")

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

    def start(self, **options):
        device = self.root / "printer [1] with spaces"
        device.touch()
        self.section("printer", str(device), enabled="1", **options)
        capture = self.root / "capture.py"
        capture.write_text("import json, sys\n"
                           "with open(sys.argv[1], 'a') as f:\n"
                           "    f.write(json.dumps(sys.argv[2:]) + '\\n')\n")
        record = shlex.join(["python3", str(capture), str(self.root / "calls")])
        stubs = '''
config_get() {
	local result
	result=$(uci -q get "p910nd.$2.$3")
	export "$1=${result:-$4}"
}
config_get_bool() { config_get "$@"; }
append() { export "$1=${args:+$args }$2"; }
procd_open_instance() { :; }
procd_close_instance() { :; }
logger() { :; }
'''
        self.shell(stubs + "procd_set_param() { " + record + ' "$@"; }\n'
                   + "procd_add_mdns() { " + record + ' mdns "$@"; }\n'
                   + INIT.read_text() + "\nstart_p910nd printer\n")
        return device, [json.loads(line) for line in (self.root / "calls").read_text().splitlines()]

    def test_init_preserves_arguments(self):
        device, calls = self.start(port="2", bind="fe80::1%br-lan", bidirectional="1")
        command = next(call for call in calls if call[0] == "command")
        self.assertEqual(command, ["command", "/usr/sbin/p910nd", "-d", "-b",
                                   "-f", str(device), "-i", "fe80::1%br-lan", "2"])

    def test_init_default_port_matches_mdns(self):
        _, calls = self.start(mdns="1", mdns_ty="Test printer")
        command = next(call for call in calls if call[0] == "command")
        mdns = next(call for call in calls if call[0] == "mdns")
        self.assertEqual(command[-1], "0")
        self.assertEqual(mdns[:4], ["mdns", "pdl-datastream", "tcp", "9100"])

    def test_remove_does_not_access_sysfs(self):
        result = self.shell("ACTION=remove\nDEVNAME=usb/lp0\n" + HOTPLUG.read_text())
        self.assertEqual(result.stderr, "")


if __name__ == "__main__":
    unittest.main(verbosity=2)

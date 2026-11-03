#!/usr/bin/env python3
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


PACKAGE = Path(__file__).resolve().parents[1]
HARNESS = r"""
log() { printf '%s\n' "$*" >> "$MOCK_DIR/trace"; }
listlp() {
    printf '%s\n' "$MOCK_DIR/dev/usb/lp0,3f0/4117/100,HP LaserJet 1018,HP LaserJet 1018,port-A"
}
logger() { log "$*"; }
lock() { log "LOCK $*"; }
sleep() { log "SLEEP $*"; }
usb_printerid() {
    read -r count < "$MOCK_DIR/queries"
    count=$((count + 1))
    printf '%s\n' "$count" > "$MOCK_DIR/queries"
    log "QUERY $count $*"
    case "$MODE:$count" in
        query_busy:*|query_busy_once:1|loaded_then_busy:[2-9]*) return 1 ;;
    esac
    case "$MODE" in
        loaded_then_busy|query_busy_once) printf '%s\n' 'MDL:HP LaserJet 1018;FWVER:20260101;' ;;
        *) printf '%s\n' 'MDL:HP LaserJet 1018;' ;;
    esac
}
cat() {
    read -r count < "$MOCK_DIR/uploads"
    count=$((count + 1))
    printf '%s\n' "$count" > "$MOCK_DIR/uploads"
    log "UPLOAD $count $*"
    case "$MODE:$count" in
        write_failure:*|write_failure_once:1) return 1 ;;
    esac
    return 0
}
ACTION=bind
DEVTYPE=usb_interface
PRODUCT=3f0/4117/100
DEVPATH=/devices/port-A/1-1:1.0
. "$HOTPLUG"
wait
"""


class HotplugTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.busybox = shutil.which("busybox")
        if cls.busybox is None:
            raise unittest.SkipTest("BusyBox ash is required")

    def run_hotplug(self, mode):
        with tempfile.TemporaryDirectory(prefix="p910nd-hotplug-test-") as td:
            root = Path(td)
            for name in ("queries", "uploads"):
                (root / name).write_text("0\n")
            device = root / "dev/usb/lp0"
            device.parent.mkdir(parents=True)
            device.symlink_to("/dev/null")
            firmware = root / "usr/share/p910nd/firmware/sihp1018.dl"
            firmware.parent.mkdir(parents=True)
            firmware.write_bytes(b"firmware")

            # Redirect filesystem roots while executing the actual hotplug logic.
            source = (PACKAGE / "25-usb-printer-helper.hotplug").read_text()
            for prefix in ("/sys", "/dev/usb", "/usr/share/p910nd", "/var/run"):
                source = source.replace(prefix, str(root) + prefix)
            script = root / "hotplug"
            script.write_text(source)
            result = subprocess.run(
                [self.busybox, "ash", "-c", HARNESS],
                capture_output=True, text=True, timeout=5,
                env=dict(os.environ, MOCK_DIR=td, MODE=mode, HOTPLUG=str(script)),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, "")
            return (root / "trace").read_text().splitlines()

    def test_loaded_printer_is_not_reopened_or_reflashed(self):
        trace = self.run_hotplug("loaded_then_busy")
        self.assertFalse(any(line.startswith("UPLOAD ") for line in trace), trace)
        self.assertTrue(any("Firmware already there" in line for line in trace), trace)

    def test_query_failure_is_retried_without_flashing(self):
        trace = self.run_hotplug("query_busy_once")
        self.assertFalse(any(line.startswith("UPLOAD ") for line in trace), trace)
        self.assertEqual(sum(line.startswith("QUERY ") for line in trace), 2, trace)
        self.assertTrue(any("Firmware already there" in line for line in trace), trace)

    def test_persistent_query_failure_never_sends_firmware(self):
        trace = self.run_hotplug("query_busy")
        self.assertFalse(any(line.startswith("UPLOAD ") for line in trace), trace)
        self.assertEqual(sum(line.startswith("QUERY ") for line in trace), 30, trace)

    def test_missing_firmware_is_uploaded(self):
        trace = self.run_hotplug("needs_firmware")
        self.assertEqual(sum(line.startswith("UPLOAD ") for line in trace), 1, trace)
        self.assertTrue(any("Done. Firmware download" in line for line in trace), trace)

    def test_failed_upload_is_retried_before_reporting_success(self):
        trace = self.run_hotplug("write_failure_once")
        self.assertEqual(sum(line.startswith("UPLOAD ") for line in trace), 2, trace)
        failures = [i for i, line in enumerate(trace) if "Firmware download failed" in line]
        successes = [i for i, line in enumerate(trace) if "Done. Firmware download" in line]
        self.assertEqual(len(failures), 1, trace)
        self.assertEqual(len(successes), 1, trace)
        self.assertLess(failures[0], successes[0], trace)

    def test_persistent_upload_failure_is_never_reported_as_success(self):
        trace = self.run_hotplug("write_failure")
        self.assertEqual(sum(line.startswith("UPLOAD ") for line in trace), 30, trace)
        self.assertFalse(any("Done. Firmware download" in line for line in trace), trace)


if __name__ == "__main__":
    unittest.main()

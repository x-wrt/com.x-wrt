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
    case "$MODE" in appears_while_waiting|appears_later) return 0 ;; esac
    printf '%s\n' "$MOCK_DIR/dev/usb/lp0,3f0/4117/100,HP LaserJet 1018,HP LaserJet 1018,port-A"
    if [ "$MODE" = two_printers ]; then
        printf '%s\n' "$MOCK_DIR/dev/usb/lp1,3f0/4117/100,HP LaserJet 1018,HP LaserJet 1018,port-B"
    fi
}
logger() { log "$*"; }
lock() {
    log "LOCK $*"
    [ "$1" = '-u' ] && return 0
    case "$MODE" in
        stale_product)
            printf '%s\n' 'PRODUCT=3f0/4917/100' > "$MOCK_INTERFACE/uevent"
            ;;
        stale_path)
            ln -sfn "$MOCK_DIR/sys/devices/port-B/1-2:1.0" "$MOCK_DIR/sys/class/usbmisc/lp0/device"
            ;;
        appears_while_waiting)
            mkdir -p "$MOCK_INTERFACE/usbmisc/lp0"
            ;;
        lock_failure) return 1 ;;
    esac
    return 0
}
readlink() {
    if [ "$MODE" = changes_after_open ]; then
        printf '%s\n' 'PRODUCT=3f0/4917/100' > "$MOCK_INTERFACE/uevent"
    fi
    command readlink "$@"
}
sleep() {
    log "SLEEP $*"
    if [ "$MODE" = appears_later ] && [ "$1" = 1 ]; then
        mkdir -p "$MOCK_INTERFACE/usbmisc/lp0"
    fi
}
usb_printerid() {
    read -r count < "$MOCK_DIR/queries"
    count=$((count + 1))
    printf '%s\n' "$count" > "$MOCK_DIR/queries"
    log "QUERY $count $*"
    case "$MODE:$count" in
        query_busy:*|query_busy_once:1|loaded_then_busy:[2-9]*) return 1 ;;
    esac
    if [ "$MODE" = replace_after_query ]; then
        rm "$MOCK_DIR/dev/usb/lp0"
        ln -s "$MOCK_DIR/replacement" "$MOCK_DIR/dev/usb/lp0"
        printf '%s\n' 'PRODUCT=3f0/4917/100' > "$MOCK_INTERFACE/uevent"
    fi
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
    command cat "$@"
}
ACTION=$MOCK_ACTION
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

    def run_hotplug(self, mode, action="bind"):
        with tempfile.TemporaryDirectory(prefix="p910nd-hotplug-test-") as td:
            root = Path(td)
            for name in ("queries", "uploads"):
                (root / name).write_text("0\n")
            (root / "replacement").write_bytes(b"do not overwrite")
            device = root / "dev/usb/lp0"
            device.parent.mkdir(parents=True)
            device.symlink_to("/dev/null")
            firmware = root / "usr/share/p910nd/firmware/sihp1018.dl"
            firmware.parent.mkdir(parents=True)
            firmware.write_bytes(b"firmware")
            interface = root / "sys/devices/port-A/1-1:1.0"
            (interface / "usbmisc/lp0").mkdir(parents=True)
            (interface / "uevent").write_text("PRODUCT=3f0/4117/100\n")
            (interface / "bInterfaceClass").write_text("07\n")
            usbmisc = root / "sys/class/usbmisc/lp0"
            usbmisc.mkdir(parents=True)
            (usbmisc / "device").symlink_to(interface, target_is_directory=True)
            other_interface = root / "sys/devices/port-B/1-2:1.0"
            other_interface.mkdir(parents=True)
            if mode in ("appears_while_waiting", "appears_later"):
                (interface / "usbmisc/lp0").rmdir()
            elif mode == "non_printer":
                (interface / "bInterfaceClass").write_text("06\n")
            elif mode == "two_printers":
                (device.parent / "lp1").symlink_to("/dev/null")
                (other_interface / "usbmisc/lp1").mkdir(parents=True)
                (other_interface / "uevent").write_text("PRODUCT=3f0/4117/100\n")
                other_usbmisc = usbmisc.parent / "lp1"
                other_usbmisc.mkdir()
                (other_usbmisc / "device").symlink_to(other_interface, target_is_directory=True)

            # Redirect filesystem roots while executing the actual hotplug logic.
            source = (PACKAGE / "25-usb-printer-helper.hotplug").read_text()
            for prefix in ("/sys", "/dev/usb", "/usr/share/p910nd", "/var/run"):
                source = source.replace(prefix, str(root) + prefix)
            script = root / "hotplug"
            script.write_text(source)
            result = subprocess.run(
                [self.busybox, "ash", "-c", HARNESS],
                capture_output=True, text=True, timeout=5,
                env=dict(os.environ, MOCK_DIR=td, MOCK_INTERFACE=str(interface),
                         MODE=mode, MOCK_ACTION=action, HOTPLUG=str(script)),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, "")
            self.assertEqual((root / "replacement").read_bytes(), b"do not overwrite")
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

    def test_replaced_product_is_not_queried_or_flashed(self):
        trace = self.run_hotplug("stale_product")
        self.assertFalse(any(line.startswith(("QUERY ", "UPLOAD ")) for line in trace), trace)

    def test_reused_node_on_another_interface_is_not_flashed(self):
        trace = self.run_hotplug("stale_path")
        self.assertFalse(any(line.startswith(("QUERY ", "UPLOAD ")) for line in trace), trace)

    def test_identity_is_rechecked_after_opening_the_device(self):
        trace = self.run_hotplug("changes_after_open")
        self.assertFalse(any(line.startswith(("QUERY ", "UPLOAD ")) for line in trace), trace)

    def test_replacement_after_query_does_not_receive_firmware(self):
        trace = self.run_hotplug("replace_after_query")
        self.assertEqual(sum(line.startswith("UPLOAD ") for line in trace), 1, trace)
        self.assertTrue(any("Done. Firmware download" in line for line in trace), trace)

    def test_device_is_discovered_after_acquiring_the_lock(self):
        trace = self.run_hotplug("appears_while_waiting")
        self.assertEqual(sum(line.startswith("UPLOAD ") for line in trace), 1, trace)

    def test_initial_add_waits_for_the_printer_node(self):
        trace = self.run_hotplug("appears_later", action="add")
        self.assertEqual(sum(line.startswith("UPLOAD ") for line in trace), 1, trace)

    def test_only_the_event_interface_receives_firmware(self):
        trace = self.run_hotplug("two_printers")
        self.assertEqual(sum(line.startswith("UPLOAD ") for line in trace), 1, trace)

    def test_non_printer_interface_does_not_acquire_the_lock(self):
        trace = self.run_hotplug("non_printer")
        self.assertFalse(any(line.startswith(("LOCK ", "QUERY ", "UPLOAD ")) for line in trace), trace)

    def test_lock_failure_does_not_query_or_flash_the_device(self):
        trace = self.run_hotplug("lock_failure")
        self.assertFalse(any(line.startswith(("QUERY ", "UPLOAD ")) for line in trace), trace)


if __name__ == "__main__":
    unittest.main()

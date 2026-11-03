#!/usr/bin/env python3
import hashlib
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
        *) printf '%s\n' "$MOCK_DEVICE_ID" ;;
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
PRODUCT=$MOCK_PRODUCT
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

    def run_hotplug(self, mode, action="bind", product="3f0/4117/100",
                    device_id="MDL:HP LaserJet 1018;", missing_firmware=None):
        with tempfile.TemporaryDirectory(prefix="p910nd-hotplug-test-") as td:
            root = Path(td)
            for name in ("queries", "uploads"):
                (root / name).write_text("0\n")
            (root / "replacement").write_bytes(b"do not overwrite")
            device = root / "dev/usb/lp0"
            device.parent.mkdir(parents=True)
            device.symlink_to("/dev/null")
            firmware_dir = root / "usr/share/p910nd/firmware"
            firmware_dir.mkdir(parents=True)
            for source in (PACKAGE / "firmware").glob("*.dl"):
                if source.name != missing_firmware:
                    (firmware_dir / source.name).write_bytes(source.name.encode())
            interface = root / "sys/devices/port-A/1-1:1.0"
            (interface / "usbmisc/lp0").mkdir(parents=True)
            (interface / "uevent").write_text("PRODUCT=" + product + "\n")
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
                         MODE=mode, MOCK_ACTION=action, HOTPLUG=str(script),
                         MOCK_PRODUCT=product, MOCK_DEVICE_ID=device_id),
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

    def test_supported_models_select_their_firmware(self):
        printers = (
            ("517", "hp LaserJet 1000", "sihp1000.dl"),
            ("1317", "hp LaserJet 1005 series", "sihp1005.dl"),
            ("4117", "HP LaserJet 1018", "sihp1018.dl"),
            ("4117", "HP LaserJet 1018s", "sihp1018.dl"),
            ("2b17", "HP LaserJet 1020", "sihp1020.dl"),
            ("2b17", "HP LaserJet 1020 Plus", "sihp1020.dl"),
            ("3d17", "HP LaserJet P1005", "sihpP1005.dl"),
            ("3e17", "HP LaserJet P1006", "sihpP1006.dl"),
            ("3e17", "HP LaserJet P1009", "sihpP1008.dl"),
            ("4817", "HP LaserJet P1007", "sihpP1007.dl"),
            ("4917", "HP LaserJet P1008", "sihpP1008.dl"),
            ("3f17", "HP LaserJet P1505", "sihpP1505.dl"),
        )
        for pid, model, firmware in printers:
            with self.subTest(model=model):
                trace = self.run_hotplug(
                    "needs_firmware", product="3f0/" + pid + "/120",
                    device_id="GET_DEVICE_ID string:\nMFG:Hewlett-Packard;MDL:" + model + ";",
                )
                uploads = [line for line in trace if line.startswith("UPLOAD ")]
                self.assertEqual(len(uploads), 1, trace)
                self.assertTrue(uploads[0].endswith("/" + firmware), trace)

    def test_p1009_model_field_and_case_variants(self):
        for device_id in (
            "mdl:hp laserjet p1009;",
            "MODEL:LaserJet P1009;",
            "MFG:HP; MDL: HP LaserJet P1009 ;",
        ):
            with self.subTest(device_id=device_id):
                trace = self.run_hotplug(
                    "needs_firmware", product="3f0/3e17/100", device_id=device_id,
                )
                uploads = [line for line in trace if line.startswith("UPLOAD ")]
                self.assertEqual(len(uploads), 1, trace)
                self.assertTrue(uploads[0].endswith("/sihpP1008.dl"), trace)

    def test_p1009_reused_payload_matches_audited_hplip_firmware(self):
        # HPLIP 3.26.4: gzip-decompressed hp_laserjet_p1009.fw.gz.
        # Changing this shared blob requires rechecking P1009 compatibility.
        payload = (PACKAGE / "firmware/sihpP1008.dl").read_bytes()
        self.assertEqual(
            hashlib.sha256(payload).hexdigest(),
            "dcb23baee83d463f7f8fa8d3235302280535ee7c673d4f21cdbe2146d446ec33",
        )

    def test_resident_firmware_and_unverified_models_are_not_flashed(self):
        printers = (
            ("3b17", "M1005"),
            ("2c17", "1022"),
            ("2d17", "1022n"),
            ("3017", "1022nw"),
            ("4017", "P1505n"),
            ("2a", "Professional P1102"),
            ("32a", "Professional P1102w"),
            ("102a", "Professional P 1102w"),
            ("92a", "Professional P1566"),
            ("92a", "Professional P1567"),
            ("92a", "Professional P1568"),
            ("92a", "Professional P1569"),
        )
        for pid, model in printers:
            with self.subTest(model=model):
                trace = self.run_hotplug(
                    "needs_firmware", product="3f0/" + pid + "/100",
                    device_id="MDL:HP LaserJet " + model + ";",
                )
                self.assertFalse(any(line.startswith(("LOCK ", "QUERY ", "UPLOAD "))
                                     for line in trace), trace)

    def test_shared_or_stale_usb_id_requires_a_matching_model(self):
        for pid, device_id in (
            ("4117", "MDL:HP LaserJet P1505n;"),
            ("3e17", "MDL:HP LaserJet P1102;"),
            ("3e17", "MDL:HP LaserJet P10090;"),
            ("3e17", "DES:HP LaserJet P1009;"),
            ("3e17", "MDL:;"),
            ("3e17", ""),
            ("3f17", "MDL:HP LaserJet P1505n;"),
        ):
            with self.subTest(pid=pid, device_id=device_id):
                trace = self.run_hotplug(
                    "needs_firmware", product="3f0/" + pid + "/100",
                    device_id=device_id,
                )
                self.assertFalse(any(line.startswith("UPLOAD ") for line in trace), trace)
                self.assertTrue(any("Skipping unexpected printer model" in line
                                    for line in trace), trace)

    def test_missing_p1009_payload_never_falls_back_to_p1006(self):
        trace = self.run_hotplug(
            "needs_firmware", product="3f0/3e17/100",
            device_id="MDL:HP LaserJet P1009;", missing_firmware="sihpP1008.dl",
        )
        self.assertFalse(any(line.startswith("UPLOAD ") for line in trace), trace)

    def test_firmware_marker_must_be_a_device_id_field(self):
        trace = self.run_hotplug(
            "needs_firmware", device_id="MDL:HP LaserJet 1018;DES:FWVER:fake;",
        )
        self.assertEqual(sum(line.startswith("UPLOAD ") for line in trace), 1, trace)

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

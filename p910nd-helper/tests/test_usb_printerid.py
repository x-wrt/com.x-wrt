#!/usr/bin/env python3
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


PACKAGE = Path(__file__).resolve().parents[1]


class PrinterIdTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.TemporaryDirectory(prefix="p910nd-printerid-test-")
        cls.addClassCleanup(cls.work.cleanup)
        work = Path(cls.work.name)
        wrapper = work / "ioctl.c"
        wrapper.write_text(r"""
#include <stdarg.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>

int __wrap_open(const char *path, int flags, ...)
{
    (void)path;
    (void)flags;
    if (getenv("MOCK_STDIN_DEVICE")) {
        errno = EBUSY;
        return -1;
    }
    return 100;
}

int __wrap_close(int fd)
{
    (void)fd;
    return 0;
}

int __wrap_ioctl(int fd, unsigned long request, ...)
{
    va_list ap;
    unsigned char *out;
    int declared = atoi(getenv("MOCK_ID_LENGTH"));
    size_t copied = declared < 2 ? 2 : declared >= 1024 ? 1023 : declared;

    if (getenv("MOCK_STDIN_DEVICE") && fd != 0) {
        errno = EBADF;
        return -1;
    }
    va_start(ap, request);
    out = va_arg(ap, unsigned char *);
    va_end(ap);

    /* usblp limits its copy without rewriting the device's length header. */
    if (copied > _IOC_SIZE(request))
        copied = _IOC_SIZE(request);
    memset(out, 'A', copied);
    out[0] = declared >> 8;
    out[1] = declared & 255;
    return 0;
}
""")
        cls.binary = work / "usb_printerid"
        compiler = shlex.split(os.environ.get("P910ND_TEST_CC", "cc"))
        flags = shlex.split(os.environ.get("P910ND_TEST_CFLAGS", ""))
        subprocess.run([
            *compiler, "-Wall", "-Wextra", "-Werror", *flags,
            str(PACKAGE / "src/usb_printerid.c"), str(wrapper),
            "-Wl,--wrap=open", "-Wl,--wrap=ioctl", "-Wl,--wrap=close",
            "-o", str(cls.binary),
        ], check=True)

    def query(self, length, stdin_device=False):
        env = dict(os.environ, MOCK_ID_LENGTH=str(length))
        if stdin_device:
            env["MOCK_STDIN_DEVICE"] = "1"
        return subprocess.run(
            [str(self.binary), "-" if stdin_device else "/mock/lp0"],
            capture_output=True, timeout=5, env=env,
        )

    def test_queries_inherited_device_without_reopening_it(self):
        result = self.query(32, stdin_device=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b"GET_DEVICE_ID string:\n" + b"A" * 30 + b"\n")

    def test_valid_lengths(self):
        for length in (2, 32, 1023):
            with self.subTest(length=length):
                result = self.query(length)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    result.stdout,
                    b"GET_DEVICE_ID string:\n" + b"A" * (length - 2) + b"\n",
                )

    def test_rejects_invalid_lengths_without_output(self):
        for length in (0, 1, 1025, 65535):
            with self.subTest(length=length):
                result = self.query(length)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(result.stdout, b"")
                self.assertIn(b"invalid device ID length", result.stderr)

    def test_truncated_copy_does_not_expose_uninitialized_memory(self):
        result = self.query(1024)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout,
            b"GET_DEVICE_ID string:\n" + b"A" * 1021 + b"\0\n",
        )


if __name__ == "__main__":
    unittest.main()

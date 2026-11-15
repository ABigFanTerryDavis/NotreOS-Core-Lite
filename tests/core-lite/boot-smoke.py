#!/usr/bin/env python3
"""Boot a Core Lite ISO in UEFI QEMU and wait for its branded live login."""
from __future__ import annotations

import argparse
import os
import select
import shutil
import subprocess
import sys
import time


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("iso")
    parser.add_argument("firmware_code", help="non-secure OVMF_CODE pflash image")
    parser.add_argument("firmware_vars", help="writable copy of the matching OVMF_VARS image")
    parser.add_argument("--timeout", type=int, default=360)
    args = parser.parse_args()

    qemu = shutil.which("qemu-system-x86_64")
    if not qemu:
        parser.error("qemu-system-x86_64 is not installed")
    if not all(os.path.isfile(path) for path in (args.iso, args.firmware_code, args.firmware_vars)):
        parser.error("ISO or OVMF CODE/VARS firmware path does not exist")

    command = [
        qemu,
        "-machine", "q35,accel=tcg",
        "-m", "4096",
        "-smp", "2",
        "-drive", f"if=pflash,format=raw,unit=0,readonly=on,file={args.firmware_code}",
        "-drive", f"if=pflash,format=raw,unit=1,file={args.firmware_vars}",
        "-cdrom", args.iso,
        "-boot", "order=d",
        "-display", "none",
        "-serial", "stdio",
        "-monitor", "none",
        "-no-reboot",
    ]
    print("Starting Core Lite UEFI boot smoke test:", " ".join(command), flush=True)
    proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = bytearray()
    deadline = time.monotonic() + args.timeout
    marker = b"NotreOS Core Lite 0.0.1"
    try:
        assert proc.stdout is not None
        fd = proc.stdout.fileno()
        os.set_blocking(fd, False)
        while time.monotonic() < deadline:
            ready, _, _ = select.select([fd], [], [], 1.0)
            if ready:
                chunk = os.read(fd, 65536)
                if chunk:
                    output.extend(chunk)
                    sys.stdout.buffer.write(chunk)
                    sys.stdout.buffer.flush()
                    if marker in output:
                        print("\nCore Lite reached the branded live serial login.", flush=True)
                        return 0
            if proc.poll() is not None:
                break
        tail = bytes(output[-12000:]).decode("utf-8", errors="replace")
        print("\nCore Lite did not reach the branded live login before timeout or QEMU exit.", file=sys.stderr)
        print(tail, file=sys.stderr)
        return 1
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)
        if proc.stdout:
            proc.stdout.close()


if __name__ == "__main__":
    raise SystemExit(main())

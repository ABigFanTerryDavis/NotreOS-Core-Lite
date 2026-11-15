#!/usr/bin/env python3
"""Boot the live ISO with a real virtual display and assert the XFCE desktop appears."""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def read_desktop_text(xwd_path: Path, png_path: Path) -> str:
    subprocess.run(
        ["xwd", "-root", "-silent", "-out", str(xwd_path)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        timeout=20,
    )
    subprocess.run(
        ["convert", str(xwd_path), "-resize", "160%", "-colorspace", "Gray",
         "-contrast", "-contrast", str(png_path)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        timeout=30,
    )
    result = subprocess.run(
        ["tesseract", str(png_path), "stdout", "--psm", "11"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=30,
    )
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("iso")
    parser.add_argument("firmware_code", help="non-secure OVMF_CODE pflash image")
    parser.add_argument("firmware_vars", help="writable copy of the matching OVMF_VARS image")
    parser.add_argument("screenshot", help="PNG path to save the successful desktop capture")
    parser.add_argument("--timeout", type=int, default=420)
    args = parser.parse_args()

    qemu = shutil.which("qemu-system-x86_64")
    missing_tools = [tool for tool in ("xwd", "convert", "tesseract") if not shutil.which(tool)]
    if not qemu:
        parser.error("qemu-system-x86_64 is not installed")
    if missing_tools:
        parser.error(f"graphical smoke-test tools are not installed: {', '.join(missing_tools)}")
    if not all(os.path.isfile(path) for path in (args.iso, args.firmware_code, args.firmware_vars)):
        parser.error("ISO or OVMF CODE/VARS firmware path does not exist")

    screenshot = Path(args.screenshot)
    screenshot.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="notreos-gui-smoke-") as temp:
        temp_dir = Path(temp)
        xwd_path = temp_dir / "desktop.xwd"
        png_path = temp_dir / "desktop.png"
        serial_path = temp_dir / "serial.log"
        qemu_log_path = temp_dir / "qemu.log"
        command = [
            qemu,
            "-machine", "q35,accel=tcg",
            "-m", "4096",
            "-smp", "2",
            "-drive", f"if=pflash,format=raw,unit=0,readonly=on,file={args.firmware_code}",
            "-drive", f"if=pflash,format=raw,unit=1,file={args.firmware_vars}",
            "-cdrom", args.iso,
            "-boot", "order=d",
            "-display", "gtk",
            "-serial", f"file:{serial_path}",
            "-monitor", "none",
            "-no-reboot",
            "-nic", "none",
            "-vga", "std",
        ]
        print("Starting Core Lite graphical UEFI smoke test:", " ".join(command), flush=True)

        last_text = ""
        deadline = time.monotonic() + args.timeout
        with qemu_log_path.open("wb") as qemu_log:
            proc = subprocess.Popen(command, stdout=qemu_log, stderr=subprocess.STDOUT)
            try:
                while time.monotonic() < deadline:
                    if proc.poll() is not None:
                        break
                    time.sleep(8)
                    try:
                        last_text = read_desktop_text(xwd_path, png_path)
                    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
                        print(f"GUI capture is not ready yet: {exc}", flush=True)
                        continue
                    folded = re.sub(r"[^a-z0-9]+", " ", last_text.casefold())
                    found = [marker for marker in ("welcome", "epiphany", "thunar") if marker in folded]
                    if len(found) == 3:
                        shutil.copy2(png_path, screenshot)
                        print("Core Lite graphical smoke passed: the live desktop's NotreOS Welcome window is visible.")
                        print("OCR markers: Welcome, Epiphany, Thunar")
                        print(f"Desktop screenshot: {screenshot}")
                        print("Recognized desktop text:\n" + last_text, flush=True)
                        return 0
                if png_path.is_file():
                    shutil.copy2(png_path, screenshot)
                qemu_log.flush()
                tail = qemu_log_path.read_text(errors="replace")[-12000:]
                serial = serial_path.read_text(errors="replace")[-6000:] if serial_path.exists() else ""
                print("Core Lite did not display the NotreOS desktop before timeout or QEMU exit.", file=sys.stderr)
                print("Last OCR result:\n" + last_text, file=sys.stderr)
                print("Serial output:\n" + serial, file=sys.stderr)
                print("QEMU output:\n" + tail, file=sys.stderr)
                return 1
            finally:
                if proc.poll() is None:
                    proc.terminate()
                    try:
                        proc.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        proc.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())

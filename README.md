# NotreOS Core Lite 0.0.1

NotreOS Core Lite is a custom minimal live image based on the official Zorin OS 18.1 Lite package profile and Ubuntu 24.04 LTS. It is built from signed Zorin Stable and Patches archives rather than by respinning the full Zorin ISO. The Patches archive supplies the XFCE 4.20 desktop package that matches Zorin's updated windowing and panel packages.

The image starts Zorin's packaged Lite XFCE session with NotreOS branding: a NotreOS theme and wallpaper, a branded Zorin Menu Lite button, and a first-run Welcome page. Epiphany, Thunar, Mousepad, Ristretto, File Roller, and XFCE Terminal are included for offline use. The planned size aim is 700–800 MiB; the actual ISO size is measured and reported by each build, not guaranteed.

See [the Core Lite build notes](core-lite/README.md) for the package base, archive verification, dependencies, and licensing details.

## Build locally

On Ubuntu 24.04, install `debootstrap`, `curl`, `gnupg`, `grub-efi-amd64-bin`, `grub-pc-bin`, `mtools`, `squashfs-tools`, and `xorriso`, then run:

```sh
sudo ./scripts/build-core-lite.sh
./tests/core-lite/smoke.sh
```

The image and its manifest/checksums are written under `output/core-lite/images/`. GitHub Actions also builds the ISO, validates the live root, and performs a UEFI/QEMU boot smoke test in the [Core Lite workflow](https://github.com/ABigFanTerryDavis/NotreOS-Core-Lite/actions/workflows/build-core-lite.yml).

## License

NotreOS-authored files are licensed under [GPL-3.0](LICENSE). Third-party packages in the image retain their own licenses; see [Core Lite third-party notices](core-lite/THIRD-PARTY-NOTICES.md). The Ancient 0.0.1 edition is maintained separately in the [NotreOS repository](https://github.com/ABigFanTerryDavis/NotreOS).

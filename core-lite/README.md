# NotreOS Core Lite 0.0.1

Core Lite is NotreOS's new, separate desktop edition. It is based on the official Zorin OS 18.1 Lite package profile, not merely on generic Ubuntu with XFCE: the build installs Zorin's `zorin-os-lite-desktop-minimal`, Lite default/live settings, Zorin Menu Lite panel plug-in, and its supporting desktop packages from Zorin's signed Noble Stable and Patches Launchpad archives. The base system is Ubuntu 24.04 LTS (Noble), matching [Zorin OS 18.1's published technical details](https://zorin.com/os/details/); Zorin says the 18 series is supported through 1 June 2029 and that Lite remains available in the 17 and 18 series in its [Lite-edition statement](https://help.zorin.com/docs/getting-started/getting-zorin-os-lite/).

The build does not download or respin the full, multi-gigabyte Zorin ISO. It creates a minimal Noble root with `debootstrap`, then installs the exact Zorin Lite package profile from the [official Zorin Stable](https://launchpad.net/~zorinos/+archive/ubuntu/stable) and [Zorin Patches](https://launchpad.net/~zorinos/+archive/ubuntu/patches) archives, which both publish the same verified signing-key fingerprint. The Patches archive supplies the XFCE 4.20 desktop component that matches the Zorin Stable windowing and panel packages; without it, Noble's older XFCE 4.18 desktop component conflicts with Zorin's packages. Zorin lists its public archives among its [official package sources](https://zorin.com/about/). The builder verifies the signing key before enabling either source and relies on APT's signed `InRelease` metadata and package checksums.

## P4DE starter and offline apps

LightDM starts Zorin's packaged `zorin-os-lite` Xsession entry, which launches `startxfce4`; this keeps the real Lite session underneath the initial P4DE seed. NotreOS overlays its own OS identity, wallpaper, GTK theme, panel layout, menu-button icon, and first-login Welcome page. The panel uses the actual Zorin Menu Lite plug-in, but the panel item is named NotreOS Menu and its visible menu mark is a NotreOS icon. P4DE is a starter configuration here, not an independent desktop toolkit yet.

Epiphany, Thunar, Mousepad, Ristretto, File Roller, and XFCE Terminal are included in the ISO, so these basic tools are available without downloading them after boot. NetworkManager and its panel applet are included for Wi-Fi and wired setup. The official [Zorin OS 18.1 Lite package list](https://assets.zorincdn.com/zorin.com/downloads/installed-package-lists/18/Zorin-OS-18.1-Lite.zip) is the reference for the upstream Lite profile.

The image uses Ubuntu 24.04's HWE kernel and includes the signed generic Intel Wi-Fi module package. Ubuntu's current Noble 7.0 kernel line splits these drivers into specific signed packages instead of publishing `linux-modules-extra-<kernel>`; the builder installs that legacy package only when the selected kernel version actually provides it.

## Build and test

On Ubuntu 24.04, install `debootstrap`, `curl`, `gnupg`, `grub-efi-amd64-bin`, `grub-pc-bin`, `mtools`, `squashfs-tools`, and `xorriso`, then run:

```sh
sudo ./scripts/build-core-lite.sh
./tests/core-lite/smoke.sh
```

The build creates `output/core-lite/images/notreos-core-lite-0.0.1-x86_64.iso`, a manifest, and `SHA256SUMS`. It packages the installed system as a casper squashfs live root and creates UEFI/BIOS GRUB boot entries. The repository's `Build NotreOS Core Lite` GitHub Actions workflow installs the tools, builds the image, checks the ISO and live root, then boots it under OVMF/QEMU.

The initial size aim is roughly 700–800 MiB, not a guaranteed cap. The manifest records the actual compressed-root and ISO sizes; the build warns if the ISO exceeds 800 MiB rather than truncating it or hiding the result.

## Repository and licensing

This repository contains only the Core Lite track and its dedicated build workflow. NotreOS Ancient 0.0.1 remains in the separate [NotreOS repository](https://github.com/ABigFanTerryDavis/NotreOS).

NotreOS-authored source is licensed under the repository's GPL-3.0 `LICENSE`. Zorin and Ubuntu binaries shipped in the image retain their individual upstream licenses; the build preserves package copyright notices at `/usr/share/doc/<package>/copyright`. See [Core Lite third-party notices](THIRD-PARTY-NOTICES.md) for the Zorin source and license summary.

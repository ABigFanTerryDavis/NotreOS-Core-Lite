# Core Lite third-party package notices

The repository's GPL-3.0 license covers NotreOS-authored source and configuration; it does not replace the licenses of packages included in the Core Lite live image.

## Zorin OS 18.1 Lite source

Zorin's [technical details](https://zorin.com/os/details/) identify Zorin OS 18.1 as Ubuntu 24.04 LTS (Noble), with XFCE in the Lite edition and support through 1 June 2029. Zorin publishes an [18.1 Lite installed-package list](https://assets.zorincdn.com/zorin.com/downloads/installed-package-lists/18/Zorin-OS-18.1-Lite.zip) and points to its public [Stable Launchpad archive](https://launchpad.net/~zorinos/+archive/ubuntu/stable) as an official package source on its [source-code page](https://zorin.com/about/). Zorin's [Patches Launchpad archive](https://launchpad.net/~zorinos/+archive/ubuntu/patches) is also an official Zorin OS archive for operating-system patches.

The build uses `https://ppa.launchpadcontent.net/zorinos/stable/ubuntu` and `https://ppa.launchpadcontent.net/zorinos/patches/ubuntu`, suite `noble`, component `main`. Before enabling either archive, the build downloads the public key and checks Launchpad's published signing fingerprint `B2228B8CCA5C00A2C59D35E530FCF8F64F71B61C`; both official archives publish that same key. APT then verifies each signed archive's metadata and package hashes. The installed package manifest records the exact versions used for each image.

The Patches archive supplies the XFCE 4.20 `xfdesktop4` package that matches Zorin Stable's XFCE windowing and panel updates. It prevents APT from pairing Zorin's 4.20 windowing library with Ubuntu Noble's older XFCE 4.18 desktop component. The profile explicitly installs `zorin-os-lite-desktop-minimal`, `zorin-os-lite-default-settings`, `zorin-os-lite-live-settings`, `xfce4-zorinmenulite-plugin`, and `xfdesktop4`. Zorin's package metadata makes its official Lite profile and supporting settings the base; NotreOS overlays its own user-facing identity and P4DE configuration on top. The image remains a custom package-built live system, not a copy of the full Zorin ISO.

## License handling

The Zorin Lite settings and Zorin Menu Lite plug-in copyright records inspected specify GPL-2-or-later. Zorin desktop themes specify GPL-2-or-later; the Zorin icon theme package specifies CC BY-SA 4.0. Zorin's wallpaper package uses per-file notices, including CC0-1.0 and CC BY 2.0. The Zorin artwork and GRUB theme packages also carry their own notices. These packages are distributed as separate upstream packages, not relicensed as NotreOS source.

The builder removes most documentation to keep the image small but deliberately retains every `/usr/share/doc/**/copyright` file in the live filesystem. These installed records are the authoritative license notices for each package version; review them in the built image before making any further redistribution or artwork changes. NotreOS uses its own name, release identity, Welcome page, wallpaper, and GTK/panel configuration; upstream Zorin artwork remains governed by its included notices and is not presented as NotreOS branding.

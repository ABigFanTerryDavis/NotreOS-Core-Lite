#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
IMAGE_DIR="${1:-$ROOT_DIR/output/core-lite/images}"
ISO="$IMAGE_DIR/notreos-core-lite-0.0.1-x86_64.iso"
MANIFEST="$IMAGE_DIR/notreos-core-lite-0.0.1-manifest.txt"
SUMS="$IMAGE_DIR/SHA256SUMS"
for file in "$ISO" "$MANIFEST" "$SUMS"; do
    [[ -s "$file" ]] || { echo "Missing/empty Core Lite artifact: $file" >&2; exit 1; }
done
(cd "$IMAGE_DIR" && sha256sum --check --status SHA256SUMS) || { echo 'Core Lite SHA-256 verification failed.' >&2; exit 1; }
file "$ISO" | grep -qi 'ISO 9660' || { echo 'Core Lite image is not recognized as an ISO 9660 filesystem.' >&2; file "$ISO" >&2; exit 1; }
report="$(xorriso -indev "$ISO" -report_el_torito plain 2>&1)"
printf '%s\n' "$report" | grep -qi 'UEFI' || { echo 'Core Lite ISO has no UEFI El Torito boot entry.' >&2; printf '%s\n' "$report" >&2; exit 1; }
iso_listing="$(xorriso -indev "$ISO" -ls /casper 2>&1)"
for item in filesystem.squashfs filesystem.manifest vmlinuz initrd; do
    printf '%s\n' "$iso_listing" | grep -Fq "$item" || { echo "Core Lite ISO is missing /casper/$item." >&2; printf '%s\n' "$iso_listing" >&2; exit 1; }
done

inspect_dir="$(mktemp -d)"
trap 'rm -rf "$inspect_dir"' EXIT
xorriso -osirrox on -indev "$ISO" -extract /casper/filesystem.squashfs "$inspect_dir/filesystem.squashfs" >/dev/null 2>&1
xorriso -osirrox on -indev "$ISO" -extract /casper/filesystem.manifest "$inspect_dir/filesystem.manifest" >/dev/null 2>&1
squash="$inspect_dir/filesystem.squashfs"
for package in zorin-os-lite-desktop-minimal zorin-os-lite-default-settings \
               zorin-os-lite-live-settings xfce4-zorinmenulite-plugin xfdesktop4; do
    grep -Eq "^installed ${package} " "$inspect_dir/filesystem.manifest" || {
        echo "Core Lite ISO is missing required Zorin package: $package" >&2; exit 1;
    }
done
if ! grep -Eq '^installed xfdesktop4 4\.20\.' "$inspect_dir/filesystem.manifest"; then
    echo 'Core Lite ISO must contain the Zorin-compatible XFCE 4.20 desktop package.' >&2; exit 1
fi
unsquashfs -cat "$squash" etc/notreos-release | grep -Fq 'VERSION="0.0.1"'
unsquashfs -cat "$squash" etc/casper.conf | grep -Fq 'USERNAME="notreos"'
unsquashfs -cat "$squash" etc/lightdm/lightdm.conf.d/50-notreos-core-lite.conf | grep -Fq 'user-session=zorin-os-lite'
unsquashfs -cat "$squash" usr/share/xsessions/zorin-os-lite.desktop | grep -Fq 'Exec=startxfce4'
unsquashfs -cat "$squash" usr/share/notreos/welcome/index.html | grep -Fq 'Welcome to NotreOS Core Lite'
unsquashfs -cat "$squash" usr/share/themes/NotreOS/gtk-3.0/gtk.css | grep -Fq '#168bb6'
unsquashfs -cat "$squash" etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml | grep -Fq 'value="zorinmenulite"'
unsquashfs -cat "$squash" etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml | grep -Fq 'value="notreos-menu-symbolic"'
unsquashfs -cat "$squash" usr/share/xfce4/panel/plugins/zorinmenulite.desktop | grep -Fq 'Name=NotreOS Menu'
unsquashfs -cat "$squash" usr/share/icons/hicolor/symbolic/apps/notreos-menu-symbolic.svg | grep -Fq '#168bb6'
unsquashfs -cat "$squash" etc/apt/sources.list.d/zorin.sources | grep -Fq 'https://ppa.launchpadcontent.net/zorinos/stable/ubuntu'
unsquashfs -cat "$squash" etc/apt/sources.list.d/zorin.sources | grep -Fq 'https://ppa.launchpadcontent.net/zorinos/patches/ubuntu'
unsquashfs -cat "$squash" etc/apt/sources.list.d/zorin.sources | grep -Fq 'Signed-By: /usr/share/keyrings/zorin-stable.gpg'
unsquashfs -cat "$squash" usr/share/keyrings/zorin-stable.gpg > "$inspect_dir/zorin-stable.gpg"
key_fingerprint="$(gpg --batch --show-keys --with-colons "$inspect_dir/zorin-stable.gpg" | awk -F: '$1 == "fpr" { print $10; exit }')"
[[ "$key_fingerprint" == 'B2228B8CCA5C00A2C59D35E530FCF8F64F71B61C' ]] || {
    echo "Core Lite ISO contains an unexpected Zorin archive key: $key_fingerprint" >&2; exit 1;
}
unsquashfs -cat "$squash" usr/share/doc/zorin-os-lite-default-settings/copyright | grep -Fq 'GPL-2+'
unsquashfs -cat "$squash" usr/share/doc/xfce4-zorinmenulite-plugin/copyright | grep -Fq 'GPL-2+'
unsquashfs -cat "$squash" usr/share/doc/zorin-icon-themes/copyright | grep -Fq 'CC-BY-SA-4.0'
grep -Fq 'Zorin repositories: Launchpad Zorin OS Stable and Patches PPAs' "$MANIFEST"
grep -Fq 'official Zorin OS Lite Xsession (startxfce4)' "$MANIFEST"

printf '%s\n' 'Core Lite ISO and live-root checks passed.'
printf '%s\n' "$report" | grep -E 'El Torito|UEFI|image[0-9]' || true
cat "$MANIFEST"

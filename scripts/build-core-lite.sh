#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PROFILE_DIR="$ROOT_DIR/core-lite"
OVERLAY_DIR="$PROFILE_DIR/overlay"
ISO_BOOT_DIR="$PROFILE_DIR/iso"
BUILD_DIR="${NOTREOS_CORE_LITE_BUILD_DIR:-${TMPDIR:-/tmp}/notreos-core-lite-build}"
ROOTFS_DIR="$BUILD_DIR/rootfs"
STAGE_DIR="$BUILD_DIR/iso-root"
IMAGE_DIR="$ROOT_DIR/output/core-lite/images"
ISO_NAME="notreos-core-lite-0.0.1-x86_64.iso"
SUITE="noble"
ARCH="amd64"
MIRROR="${NOTREOS_UBUNTU_MIRROR:-https://archive.ubuntu.com/ubuntu}"
ZORIN_PPA="https://ppa.launchpadcontent.net/zorinos/stable/ubuntu"
ZORIN_PATCHES_PPA="https://ppa.launchpadcontent.net/zorinos/patches/ubuntu"
ZORIN_KEY_FINGERPRINT="B2228B8CCA5C00A2C59D35E530FCF8F64F71B61C"
JOBS="${NOTREOS_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '2')}"
MOUNTS=()

fail() { printf 'Core Lite build: %s\n' "$*" >&2; exit 1; }
unmount_all() {
    local mountpoint index
    for (( index=${#MOUNTS[@]} - 1; index >= 0; index-- )); do
        mountpoint="${MOUNTS[index]}"
        if mountpoint -q "$mountpoint"; then
            umount -lf "$mountpoint" || true
        fi
    done
    MOUNTS=()
}
cleanup() { unmount_all; }
trap cleanup EXIT

[[ $EUID -eq 0 ]] || fail 'run as root (for example: sudo ./scripts/build-core-lite.sh).'
for tool in debootstrap chroot mount umount mksquashfs grub-mkrescue xorriso sha256sum curl gpg systemctl; do
    command -v "$tool" >/dev/null 2>&1 || fail "required host tool is missing: $tool"
done
[[ -s "$PROFILE_DIR/packages.txt" ]] || fail 'core-lite/packages.txt is missing or empty.'
[[ -d "$OVERLAY_DIR" && -d "$ISO_BOOT_DIR" ]] || fail 'Core Lite overlay or ISO boot files are missing.'
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail 'NOTREOS_JOBS must be a positive integer.'

mkdir -p "$BUILD_DIR" "$IMAGE_DIR"
rm -rf "$ROOTFS_DIR" "$STAGE_DIR"
mkdir -p "$ROOTFS_DIR" "$STAGE_DIR/casper" "$STAGE_DIR/boot/grub"

# Fetch the public key from Ubuntu's keyserver, but trust it only after checking
# the official Zorin Stable Launchpad fingerprint published by Launchpad.
ZORIN_KEY_ASC="$BUILD_DIR/zorin-stable.asc"
ZORIN_KEYRING="$BUILD_DIR/zorin-stable.gpg"
curl --fail --location --retry 3 \
    "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x$ZORIN_KEY_FINGERPRINT" \
    --output "$ZORIN_KEY_ASC"
actual_fingerprint="$(gpg --batch --show-keys --with-colons "$ZORIN_KEY_ASC" \
    | awk -F: '$1 == "fpr" { print $10; exit }')"
[[ "$actual_fingerprint" == "$ZORIN_KEY_FINGERPRINT" ]] \
    || fail "Zorin Stable signing-key fingerprint mismatch: $actual_fingerprint"
gpg --batch --dearmor --yes --output "$ZORIN_KEYRING" "$ZORIN_KEY_ASC"
printf 'Verified Zorin Stable PPA signing key: %s\n' "$actual_fingerprint"

printf 'Creating a minimal Ubuntu %s (%s) base, then applying the official Zorin Lite package profile.\n' "$SUITE" "$ARCH"
debootstrap \
    --arch="$ARCH" \
    --variant=minbase \
    --components=main,universe,restricted,multiverse \
    --include=ca-certificates,ubuntu-keyring \
    "$SUITE" "$ROOTFS_DIR" "$MIRROR"

install -d "$ROOTFS_DIR/usr/share/keyrings"
install -m 0644 "$ZORIN_KEYRING" "$ROOTFS_DIR/usr/share/keyrings/zorin-stable.gpg"
cat > "$ROOTFS_DIR/etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: $MIRROR
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://security.ubuntu.com/ubuntu
Suites: noble-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
cat > "$ROOTFS_DIR/etc/apt/sources.list.d/zorin.sources" <<EOF
Types: deb
URIs: $ZORIN_PPA
Suites: noble
Components: main
Signed-By: /usr/share/keyrings/zorin-stable.gpg

Types: deb
URIs: $ZORIN_PATCHES_PPA
Suites: noble
Components: main
Signed-By: /usr/share/keyrings/zorin-stable.gpg
EOF
rm -f "$ROOTFS_DIR/etc/apt/sources.list"
cat > "$ROOTFS_DIR/etc/apt/apt.conf.d/99notreos-core-lite" <<'EOF'
Acquire::Languages "none";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF

# Bind only the interfaces needed by package configuration and initramfs generation.
for mountpoint in dev dev/pts proc sys run; do
    mkdir -p "$ROOTFS_DIR/$mountpoint"
done
mount --rbind /dev "$ROOTFS_DIR/dev"
MOUNTS+=("$ROOTFS_DIR/dev")
mount --make-rslave "$ROOTFS_DIR/dev"
mount --bind /dev/pts "$ROOTFS_DIR/dev/pts"
MOUNTS+=("$ROOTFS_DIR/dev/pts")
mount --make-rslave "$ROOTFS_DIR/dev/pts"
mount -t proc proc "$ROOTFS_DIR/proc"
MOUNTS+=("$ROOTFS_DIR/proc")
mount --rbind /sys "$ROOTFS_DIR/sys"
MOUNTS+=("$ROOTFS_DIR/sys")
mount --make-rslave "$ROOTFS_DIR/sys"
mount --bind /run "$ROOTFS_DIR/run"
MOUNTS+=("$ROOTFS_DIR/run")
mount --make-rslave "$ROOTFS_DIR/run"

mapfile -t packages < <(grep -Ev '^[[:space:]]*(#|$)' "$PROFILE_DIR/packages.txt")
chroot "$ROOTFS_DIR" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get update
chroot "$ROOTFS_DIR" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends "${packages[@]}"
for package in zorin-os-lite-desktop-minimal zorin-os-lite-default-settings \
               zorin-os-lite-live-settings xfce4-zorinmenulite-plugin; do
    status="$(chroot "$ROOTFS_DIR" /usr/bin/dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)"
    [[ "$status" == 'install ok installed' ]] || fail "official Zorin Lite package is not installed: $package"
done

# Apply NotreOS identity and P4DE configuration after Zorin's official Lite defaults.
cp -a "$OVERLAY_DIR"/. "$ROOTFS_DIR"/
chroot "$ROOTFS_DIR" /usr/bin/gtk-update-icon-cache --force --quiet /usr/share/icons/hicolor
mkdir -p "$ROOTFS_DIR/usr/lib" "$ROOTFS_DIR/etc"
cat > "$ROOTFS_DIR/usr/lib/os-release" <<'EOF'
NAME="NotreOS Core Lite"
PRETTY_NAME="NotreOS Core Lite 0.0.1"
ID=ubuntu
ID_LIKE="ubuntu debian"
VERSION="Core Lite 0.0.1 (Zorin OS 18.1 Lite package profile; Ubuntu 24.04 LTS)"
VERSION_ID="24.04"
VERSION_CODENAME=noble
UBUNTU_CODENAME=noble
NOTREOS_EDITION="Core Lite"
NOTREOS_VERSION="0.0.1"
EOF
ln -sfn ../usr/lib/os-release "$ROOTFS_DIR/etc/os-release"
printf '%s\n' 'notreos' > "$ROOTFS_DIR/etc/hostname"
cat > "$ROOTFS_DIR/etc/hosts" <<'EOF'
127.0.0.1 localhost
127.0.1.1 notreos
::1 localhost ip6-localhost ip6-loopback
EOF

chroot "$ROOTFS_DIR" /usr/sbin/locale-gen en_US.UTF-8
chroot "$ROOTFS_DIR" /usr/sbin/update-locale LANG=en_US.UTF-8
kernel_file="$(find "$ROOTFS_DIR/boot" -maxdepth 1 -type f -name 'vmlinuz-*' -printf '%f\n' | sort -V | tail -n 1)"
[[ -n "$kernel_file" ]] || fail 'the Ubuntu 24.04 HWE kernel image was not installed.'
kernel_version="${kernel_file#vmlinuz-}"
extra_modules_package="linux-modules-extra-$kernel_version"
if chroot "$ROOTFS_DIR" /usr/bin/apt-cache show "$extra_modules_package" >/dev/null 2>&1; then
    chroot "$ROOTFS_DIR" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends "$extra_modules_package"
else
    printf 'No %s package is published for kernel %s; retaining the signed split HWE modules in the profile.\n' "$extra_modules_package" "$kernel_version"
fi
chroot "$ROOTFS_DIR" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get purge --yes 'linux-headers-*'
chroot "$ROOTFS_DIR" /usr/sbin/update-initramfs -u -k "$kernel_version"
systemctl --root="$ROOTFS_DIR" enable lightdm.service NetworkManager.service
systemctl --root="$ROOTFS_DIR" set-default graphical.target
[[ -s "$ROOTFS_DIR/boot/initrd.img-$kernel_version" ]] || fail "initramfs for kernel $kernel_version is missing."
install -m 0644 "$ROOTFS_DIR/boot/vmlinuz-$kernel_version" "$STAGE_DIR/casper/vmlinuz"
install -m 0644 "$ROOTFS_DIR/boot/initrd.img-$kernel_version" "$STAGE_DIR/casper/initrd"

chroot "$ROOTFS_DIR" /usr/bin/dpkg-query -W -f='${db:Status-Status} ${Package} ${Version}\n' \
    | awk '$1 == "installed" { $1 = ""; sub(/^ /, ""); print }' \
    | sort > "$STAGE_DIR/casper/filesystem.manifest"
printf '%s\n' 'Zorin/desktop/Wi-Fi package entries in the live manifest:'
grep -E '^(zorin-os|xfce4-zorinmenulite-plugin|xfdesktop4|linux-modules-iwlwifi)' "$STAGE_DIR/casper/filesystem.manifest" || true
cp "$STAGE_DIR/casper/filesystem.manifest" "$STAGE_DIR/casper/filesystem.manifest-desktop"
unmount_all
du -sx --block-size=1 "$ROOTFS_DIR" | awk '{ print $1 }' > "$STAGE_DIR/casper/filesystem.size"

# The boot kernel and initramfs are stored once on the ISO, not again in its squashfs.
find "$ROOTFS_DIR/boot" -maxdepth 1 -type f \
    \( -name 'vmlinuz-*' -o -name 'initrd.img-*' -o -name 'System.map-*' -o -name 'config-*' \) \
    -delete
rm -rf "$ROOTFS_DIR/var/lib/apt/lists"/* "$ROOTFS_DIR/var/cache/apt/archives"/* \
       "$ROOTFS_DIR/var/log/installer" "$ROOTFS_DIR/tmp"/* "$ROOTFS_DIR/var/tmp"/*
find "$ROOTFS_DIR/usr/share/doc" -type f ! -name copyright -delete 2>/dev/null || true
rm -rf "$ROOTFS_DIR/usr/share/man" "$ROOTFS_DIR/usr/share/info"
find "$ROOTFS_DIR/usr/share/locale" -mindepth 1 -maxdepth 1 \
    ! -name en ! -name en_US ! -name en_US.UTF-8 -exec rm -rf {} + 2>/dev/null || true
: > "$ROOTFS_DIR/etc/machine-id"
rm -f "$ROOTFS_DIR/var/lib/dbus/machine-id"
ln -s /etc/machine-id "$ROOTFS_DIR/var/lib/dbus/machine-id"

cp "$ISO_BOOT_DIR/boot/grub/grub.cfg" "$STAGE_DIR/boot/grub/grub.cfg"
printf 'Compressing the Zorin-profiled live root filesystem (xz, %s worker(s))...\n' "$JOBS"
mksquashfs "$ROOTFS_DIR" "$STAGE_DIR/casper/filesystem.squashfs" \
    -noappend -comp xz -b 1M -processors "$JOBS"

printf 'Creating the bootable UEFI/BIOS ISO...\n'
grub-mkrescue --output="$ROOT_DIR/output/core-lite/images/$ISO_NAME" "$STAGE_DIR"
ISO_PATH="$ROOT_DIR/output/core-lite/images/$ISO_NAME"
iso_bytes="$(stat -c '%s' "$ISO_PATH")"
rootfs_bytes="$(cat "$STAGE_DIR/casper/filesystem.size")"
squash_bytes="$(stat -c '%s' "$STAGE_DIR/casper/filesystem.squashfs")"
{
    printf 'NotreOS Core Lite 0.0.1\n'
    printf 'Architecture: x86_64 (Ubuntu package architecture: amd64)\n'
    printf 'Base system: Zorin OS 18.1 Lite official minimal/live package profile on Ubuntu 24.04 LTS (Noble)\n'
    printf 'Zorin repositories: Launchpad Zorin OS Stable and Patches PPAs, noble/main; signing key fingerprint %s\n' "$ZORIN_KEY_FINGERPRINT"
    printf 'Required Zorin Lite packages: zorin-os-lite-desktop-minimal, zorin-os-lite-default-settings, zorin-os-lite-live-settings, xfce4-zorinmenulite-plugin\n'
    printf 'Desktop: official Zorin OS Lite Xsession (startxfce4); P4DE starter, NotreOS theme/panel/menu icon, first-run Welcome\n'
    printf 'Kernel: Ubuntu 24.04 HWE kernel %s\n' "$kernel_version"
    printf 'Intel Wi-Fi: signed Ubuntu HWE iwlwifi module package; legacy linux-modules-extra only when published for this kernel\n'
    printf 'Boot: GRUB UEFI and BIOS live ISO; casper read-only squashfs\n'
    printf 'Offline apps: Epiphany browser, Thunar file manager, Mousepad editor, Ristretto image viewer, File Roller, XFCE Terminal\n'
    printf 'Installed root filesystem before compression: %s bytes (%.1f MiB)\n' \
        "$rootfs_bytes" "$(awk -v n="$rootfs_bytes" 'BEGIN { print n / 1048576 }')"
    printf 'Compressed live root filesystem: %s bytes (%.1f MiB)\n' \
        "$squash_bytes" "$(awk -v n="$squash_bytes" 'BEGIN { print n / 1048576 }')"
    printf 'ISO: %s bytes (%.1f MiB)\n' \
        "$iso_bytes" "$(awk -v n="$iso_bytes" 'BEGIN { print n / 1048576 }')"
    printf '\nSHA-256\n'
    sha256sum "$ISO_PATH"
} > "$IMAGE_DIR/notreos-core-lite-0.0.1-manifest.txt"
(
    cd "$IMAGE_DIR"
    sha256sum "$ISO_NAME" notreos-core-lite-0.0.1-manifest.txt > SHA256SUMS
)

"$ROOT_DIR/tests/core-lite/check-artifacts.sh" "$IMAGE_DIR"
iso_mib="$(awk -v n="$iso_bytes" 'BEGIN { printf "%.1f", n / 1048576 }')"
printf 'Core Lite ISO ready: %s (%s MiB)\n' "$ISO_PATH" "$iso_mib"
if (( iso_bytes > 800 * 1024 * 1024 )); then
    printf 'Core Lite size target: ISO is over 800 MiB; recording the measured size rather than hiding the overage.\n' >&2
fi

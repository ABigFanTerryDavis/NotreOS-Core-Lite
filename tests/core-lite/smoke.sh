#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
PROFILE="$ROOT_DIR/core-lite"

bash -n "$ROOT_DIR/scripts/build-core-lite.sh"
sh -n "$PROFILE/overlay/usr/bin/notreos-welcome"
python3 - "$PROFILE" <<'PY'
import pathlib
import sys
import xml.etree.ElementTree as ET

profile = pathlib.Path(sys.argv[1])
for path in sorted(profile.rglob("*.xml")):
    ET.parse(path)
for path in sorted(profile.rglob("*.svg")):
    ET.parse(path)
for path in [
    profile / "overlay/usr/share/themes/NotreOS/index.theme",
    profile / "overlay/usr/share/xfce4/panel/plugins/zorinmenulite.desktop",
]:
    text = path.read_text()
    if path.name == "index.theme":
        assert "GtkTheme=NotreOS" in text, "NotreOS GTK theme is not selected"
    else:
        assert "Name=NotreOS Menu" in text
        assert "X-XFCE-Module=zorinmenulite" in text

package_lines = [
    line.strip()
    for line in (profile / "packages.txt").read_text().splitlines()
    if line.strip() and not line.lstrip().startswith("#")
]
packages = set(package_lines)
assert len(package_lines) == len(packages), "Core Lite package profile contains duplicate entries"
required = {
    "casper", "epiphany-browser", "file-roller", "fonts-zorin-os-core",
    "libgtk-3-bin", "linux-firmware", "linux-generic-hwe-24.04",
    "linux-modules-iwlwifi-generic-hwe-24.04", "mousepad", "network-manager",
    "ristretto", "thunar", "xfdesktop4", "xfce4-panel", "xfce4-session",
    "xserver-xorg", "zorin-os-lite-desktop-minimal",
    "zorin-os-lite-default-settings", "zorin-os-lite-live-settings",
    "xfce4-zorinmenulite-plugin",
}
missing = required - packages
assert not missing, f"missing required Core Lite packages: {sorted(missing)}"
assert not ({"snapd", "ubuntu-desktop", "xfce4-whiskermenu-plugin"} & packages), \
    "Core Lite must remain minimal and use Zorin Menu Lite rather than a generic substitute"

panel = profile / "overlay/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
panel_text = panel.read_text()
assert 'value="zorinmenulite"' in panel_text, "official Zorin Lite menu plugin is not configured"
assert 'value="notreos-menu-symbolic"' in panel_text, "panel menu is not using the NotreOS icon"
assert 'value="whiskermenu"' not in panel_text, "generic Whisker Menu is still selected"
lightdm = (profile / "overlay/etc/lightdm/lightdm.conf.d/50-notreos-core-lite.conf").read_text()
assert "user-session=zorin-os-lite" in lightdm, "LightDM must start Zorin's packaged Lite session"
icon = profile / "overlay/usr/share/icons/hicolor/symbolic/apps/notreos-menu-symbolic.svg"
assert icon.is_file(), "NotreOS panel menu icon is missing"
build = (profile.parent / "scripts/build-core-lite.sh").read_text()
assert 'https://ppa.launchpadcontent.net/zorinos/stable/ubuntu' in build
assert 'https://ppa.launchpadcontent.net/zorinos/patches/ubuntu' in build
assert "B2228B8CCA5C00A2C59D35E530FCF8F64F71B61C" in build
assert "zorin-os-lite-desktop-minimal" in build and "gpg --batch --show-keys" in build
assert 'extra_modules_package="linux-modules-extra-$kernel_version"' in build
assert 'apt-cache show "$extra_modules_package"' in build
assert "${db:Status-Status} ${Package} ${Version}" in build
assert "${binary:Package}" not in build
assert "Welcome to NotreOS Core Lite" in (profile / "overlay/usr/share/notreos/welcome/index.html").read_text()
assert "notreos-welcome" in (profile / "overlay/etc/skel/.config/autostart/notreos-welcome.desktop").read_text()
print("Core Lite source smoke checks passed.")
PY

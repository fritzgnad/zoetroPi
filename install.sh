#!/bin/bash
# install.sh — one-shot installer for ZoetroPi on Raspberry Pi OS Lite (Bookworm).
# Run as root:  sudo ./install.sh
#
# What it does:
#   - installs mpv
#   - copies the player script, systemd unit, and mpv config into place
#   - masks the tty1 login prompt so the screen stays black until mpv starts
#   - patches /boot/firmware/cmdline.txt + config.txt for a silent boot
#   - enables and starts the zoetropi.service

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root: sudo $0" >&2
    exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends mpv ca-certificates

echo "==> Installing player script"
install -D -m 0755 "$HERE/scripts/zoetropi-play.sh" /usr/local/bin/zoetropi-play.sh

echo "==> Installing mpv config"
install -D -m 0644 "$HERE/config/mpv.conf" /etc/zoetropi/mpv.conf

echo "==> Installing systemd unit"
install -D -m 0644 "$HERE/systemd/zoetropi.service" /etc/systemd/system/zoetropi.service

echo "==> Preparing media + fallback video directories"
install -d -m 0755 /media/zoetropi
install -d -m 0755 /opt/zoetropi/videos
for BOOTDIR in /boot/firmware /boot; do
    [ -d "$BOOTDIR" ] || continue
    install -d -m 0755 "$BOOTDIR/videos"
    break
done

echo "==> Silencing tty1 login prompt"
systemctl disable --now getty@tty1.service 2>/dev/null || true
systemctl mask getty@tty1.service

echo "==> Patching boot command line for silent boot"
CMDLINE=/boot/firmware/cmdline.txt
[ -f "$CMDLINE" ] || CMDLINE=/boot/cmdline.txt
if [ -f "$CMDLINE" ]; then
    cp "$CMDLINE" "$CMDLINE.zoetropi.bak"
    # Ensure each flag appears exactly once.
    for flag in "quiet" "loglevel=0" "logo.nologo" "vt.global_cursor_default=0" "consoleblank=0"; do
        key="${flag%%=*}"
        # Strip any existing occurrence of the key, then append.
        sed -i "s/\b${key}\(=[^ ]*\)\?//g" "$CMDLINE"
    done
    # Collapse double-spaces and append our flags on the single line.
    sed -i 's/  */ /g; s/^ //; s/ $//' "$CMDLINE"
    sed -i "1 s|$| quiet loglevel=0 logo.nologo vt.global_cursor_default=0 consoleblank=0|" "$CMDLINE"
fi

echo "==> Patching config.txt"
CONFIG=/boot/firmware/config.txt
[ -f "$CONFIG" ] || CONFIG=/boot/config.txt
if [ -f "$CONFIG" ] && ! grep -q '^disable_splash=1' "$CONFIG"; then
    printf '\n# Added by zoetroPi\ndisable_splash=1\n' >> "$CONFIG"
fi

echo "==> Blanking /etc/issue so no banner can flash"
: > /etc/issue
: > /etc/issue.net

echo "==> Enabling service"
systemctl daemon-reload
systemctl enable zoetropi.service

cat <<EOF

ZoetroPi installed.

  * Copy .mp4 files onto a FAT32/exFAT USB stick
  * Plug the stick into the Pi
  * Reboot — the videos start automatically and loop forever

Start now without rebooting:
    sudo systemctl start zoetropi.service

Logs:
    journalctl -u zoetropi.service -f

EOF

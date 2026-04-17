#!/bin/bash -e
# pi-gen custom stage for ZoetroPi. Runs on the *host*. We drop our files
# into the rootfs, then finish up inside chroot.
#
# Assumption: the repo's scripts/systemd/config have been copied into
# ${STAGE_DIR}/00-install/files/ before pi-gen was invoked. That copy is
# done either by the GitHub Actions workflow or by running
# `pi-gen/sync-stage-files.sh` locally.

FILES="${STAGE_DIR}/00-install/files"

install -D -m 0755 "${FILES}/zoetropi-play.sh" \
    "${ROOTFS_DIR}/usr/local/bin/zoetropi-play.sh"
install -D -m 0644 "${FILES}/mpv.conf" \
    "${ROOTFS_DIR}/etc/zoetropi/mpv.conf"
install -D -m 0644 "${FILES}/zoetropi.service" \
    "${ROOTFS_DIR}/etc/systemd/system/zoetropi.service"

install -d -m 0755 "${ROOTFS_DIR}/media/zoetropi"
install -d -m 0755 "${ROOTFS_DIR}/opt/zoetropi/videos"

# Ship any bundled videos that the builder dropped alongside our files.
if compgen -G "${FILES}/videos/*" >/dev/null; then
    install -d -m 0755 "${ROOTFS_DIR}/opt/zoetropi/videos"
    cp -a "${FILES}/videos/." "${ROOTFS_DIR}/opt/zoetropi/videos/"
fi

# Silent-boot tweaks.
for CMDLINE in "${ROOTFS_DIR}/boot/firmware/cmdline.txt" "${ROOTFS_DIR}/boot/cmdline.txt"; do
    [ -f "$CMDLINE" ] || continue
    for key in quiet loglevel logo.nologo vt.global_cursor_default consoleblank; do
        sed -i "s/\b${key}\(=[^ ]*\)\?//g" "$CMDLINE"
    done
    sed -i 's/  */ /g; s/^ //; s/ $//' "$CMDLINE"
    sed -i "1 s|$| quiet loglevel=0 logo.nologo vt.global_cursor_default=0 consoleblank=0|" "$CMDLINE"
done
for CONFIG in "${ROOTFS_DIR}/boot/firmware/config.txt" "${ROOTFS_DIR}/boot/config.txt"; do
    [ -f "$CONFIG" ] || continue
    grep -q '^disable_splash=1' "$CONFIG" || printf '\n# ZoetroPi\ndisable_splash=1\n' >> "$CONFIG"
done

: > "${ROOTFS_DIR}/etc/issue"
: > "${ROOTFS_DIR}/etc/issue.net"

on_chroot <<'CHROOT'
systemctl mask getty@tty1.service
systemctl enable zoetropi.service
CHROOT

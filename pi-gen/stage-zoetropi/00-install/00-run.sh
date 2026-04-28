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

# Drop folder visible from macOS/Windows once the SD is re-inserted.
# Lives on the FAT boot partition — no Linux mounting needed on the host.
for BOOTDIR in "${ROOTFS_DIR}/boot/firmware" "${ROOTFS_DIR}/boot"; do
    [ -d "$BOOTDIR" ] || continue
    install -d -m 0755 "${BOOTDIR}/videos"
    cat > "${BOOTDIR}/videos/README.txt" <<'README'
zoetroPi — drop videos here
============================

Copy .mp4 / .mov / .mkv / .webm files into this folder.
On the next boot the Pi will play them fullscreen, looped forever.

Priority order used by the player:
  1. a plugged-in USB stick containing videos
  2. this folder (videos on the SD's boot partition)
  3. anything baked into /opt/zoetropi/videos

Notes:
  - The boot partition is small (~512 MB). For large collections, use a
    USB stick or bake videos into the image via the zoetroPi repo.
  - Deleting this README is fine.
README
done

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
    additions=""
    grep -q '^disable_splash=1'     "$CONFIG" || additions="${additions}disable_splash=1\n"
    grep -q '^disable_overscan=1'   "$CONFIG" || additions="${additions}disable_overscan=1\n"
    # 128 MB GPU/VPU memory: ensures V4L2 M2M hardware decoder has headroom on all Pi models.
    grep -q '^gpu_mem='             "$CONFIG" || additions="${additions}gpu_mem=128\n"
    # 20 s of sustained-clock boost on first boot speeds up systemd startup.
    grep -q '^initial_turbo='       "$CONFIG" || additions="${additions}initial_turbo=20\n"
    # Poll the SD card only once — shaves ~1-2 s from subsequent boots.
    grep -q '^dtparam=sd_poll_once' "$CONFIG" || additions="${additions}dtparam=sd_poll_once\n"
    grep -q '^enable_uart='         "$CONFIG" || additions="${additions}enable_uart=0\n"
    [ -n "$additions" ] && printf "\n# ZoetroPi\n${additions}" >> "$CONFIG"
done

: > "${ROOTFS_DIR}/etc/issue"
: > "${ROOTFS_DIR}/etc/issue.net"

on_chroot <<'CHROOT'
systemctl mask getty@tty1.service
systemctl enable zoetropi.service
CHROOT

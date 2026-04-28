#!/bin/bash
# zoetropi-play.sh
# Mounts the first available USB partition read-only to /media/zoetropi,
# builds a playlist of video files, and hands it to mpv for an endless,
# fullscreen, UI-less loop. Loops forever so hot-plugging a drive works.

set -u

MEDIA=/media/zoetropi
BOOTFS_DIR=/boot/firmware/videos  # fallback: videos dropped onto the SD's FAT partition
EXTRA_DIR=/opt/zoetropi/videos    # fallback: videos baked into the image
MPV_CONF=/etc/zoetropi/mpv.conf

mkdir -p "$MEDIA"

# Hide the console cursor / blank text on tty1 before any frame appears.
if [ -w /dev/tty1 ]; then
    setterm --cursor off --blank 0 --powersave off >/dev/tty1 2>/dev/null || true
    printf '\033[2J\033[H' >/dev/tty1 2>/dev/null || true
fi

find_usb_partition() {
    # Return the first /dev/sd?N partition that isn't already mounted.
    for p in /dev/sd?[0-9]; do
        [ -b "$p" ] || continue
        grep -qE "^$p " /proc/mounts && continue
        echo "$p"
        return 0
    done
    return 1
}

mount_usb() {
    local dev="$1"
    # Try common fs types; ro,nosuid,nodev for safety on an unknown drive.
    for fs in auto vfat exfat ntfs ext4; do
        if mount -t "$fs" -o ro,nosuid,nodev,noatime "$dev" "$MEDIA" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

collect_videos() {
    local root="$1"
    find "$root" -maxdepth 4 -type f \
        \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' \
        -o -iname '*.webm' -o -iname '*.m4v' -o -iname '*.avi' \) \
        2>/dev/null | sort
}

run_mpv() {
    local playlist="$1"
    local opts=(
        --fullscreen
        --vo=gpu
        --gpu-context=drm
        --hwdec=v4l2m2m-copy
        --hwdec-codecs=all
        --video-sync=display-resample
        --loop-playlist=inf
        --loop-file=inf
        --keep-open=always
        --image-display-duration=inf
        --no-osc
        --no-osd-bar
        --osd-level=0
        --cursor-autohide=always
        --no-input-default-bindings
        --input-vo-keyboard=no
        --no-input-cursor
        --no-terminal
        --really-quiet
        --msg-level=all=no
        --gapless-audio=yes
        --prefetch-playlist=yes
        --idle=no
    )
    [ -r "$MPV_CONF" ] && opts+=( "--include=$MPV_CONF" )
    mpv "${opts[@]}" --playlist="$playlist"
}

cleanup() {
    mountpoint -q "$MEDIA" && umount -l "$MEDIA" 2>/dev/null || true
}
trap cleanup EXIT

while true; do
    # Try to mount a USB stick if one is plugged in and /media/zoetropi is empty.
    if ! mountpoint -q "$MEDIA"; then
        if dev=$(find_usb_partition); then
            mount_usb "$dev" || true
        fi
    fi

    # Source priority: USB stick > videos on the SD's FAT partition > baked-in.
    videos_src=""
    if mountpoint -q "$MEDIA" && [ -n "$(collect_videos "$MEDIA")" ]; then
        videos_src="$MEDIA"
    elif [ -d "$BOOTFS_DIR" ] && [ -n "$(collect_videos "$BOOTFS_DIR")" ]; then
        videos_src="$BOOTFS_DIR"
    elif [ -d "$EXTRA_DIR" ] && [ -n "$(collect_videos "$EXTRA_DIR")" ]; then
        videos_src="$EXTRA_DIR"
    fi

    if [ -n "$videos_src" ]; then
        playlist=$(mktemp)
        collect_videos "$videos_src" >"$playlist"
        run_mpv "$playlist"
        rm -f "$playlist"
    fi

    # No videos, or mpv exited (USB pulled, bad file, etc.) — retry.
    sleep 2
done

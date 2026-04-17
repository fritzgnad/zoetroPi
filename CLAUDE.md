# zoetroPi — project memory

Raspberry Pi video-loop appliance for art installations. Flash image → Pi
boots straight into fullscreen mpv → no UI, no cursor, no login. Artists
drop `.mp4`s on a USB stick, the SD's boot partition, or bake them into a
forked image.

Repo: https://github.com/fritzgnad/zoetroPi  ·  Latest: check
[Releases](https://github.com/fritzgnad/zoetroPi/releases).

## Architecture

- `scripts/zoetropi-play.sh` — main loop. Source priority: USB stick at
  `/media/zoetropi` → `/boot/firmware/videos/` (FAT bootfs drop folder) →
  `/opt/zoetropi/videos/` (baked-in). Polls for USB, shells out to `mpv`
  with DRM/KMS output on tty1.
- `systemd/zoetropi.service` — owns tty1 (`Conflicts=getty@tty1`), runs as
  root so USB mount works without sudoers plumbing.
- `install.sh` — one-shot for existing Pi OS Lite installs. Patches
  cmdline.txt + config.txt for a silent boot and masks `getty@tty1`.
- `pi-gen/stage-zoetropi/` — custom pi-gen stage that bakes the flashable
  image. Self-contained: `pi-gen/sync-stage-files.sh` copies the canonical
  scripts/systemd/config into the stage's `files/` dir before pi-gen runs,
  so the stage folder is a single source of truth for the build.
- `.github/workflows/build-image.yml` — tag `v*` → image attached to a
  GitHub Release.

## CI gotchas (learned the hard way — do not regress these)

1. **Runner must be `ubuntu-24.04-arm`** (native arm64). On x86_64 +
   `docker/setup-qemu-action`, pi-gen's Docker container can't see the
   host's binfmt_misc registration → "arm64: not supported on this
   machine/kernel" and the build dies in ~55 s.
2. **`release: trixie`** — the default `pi-gen-version: arm64` branch is
   pinned to Debian 13 apt sources. Setting `release: bookworm` causes
   NO_PUBKEY signature errors because the keyring doesn't match.
3. **`disable-first-boot-user-rename: 1`** — without it, RPi OS shows a
   blocking "enter new username" wizard on tty1 before zoetropi.service
   can run. Defeats the whole "kiosk" point.
4. **Use the action's `image-path` output**, not a workspace glob, for
   upload-artifact and action-gh-release. The `.img.xz` lives in pi-gen's
   `deploy/` dir.

Reference: Homebridge's raspbian image workflow is a known-working
template (`homebridge/homebridge-raspbian-image`).

## Build & test loop

- Tag `vX.Y.Z` → GitHub Actions builds on `ubuntu-24.04-arm` (~15–25 min,
  native, no QEMU) → `.img.xz` attached to the v-tag release.
- Flashing on macOS: Raspberry Pi Imager → *Use custom* → `.img.xz`
  directly (no decompression). When prompted *"apply OS customisation
  settings?"* choose **No, clear settings** — our image is pre-baked.

## Supported hardware

Tested (and documented for) Pi Zero 2 W, Pi 3, Pi 4, Pi 5 on Raspberry Pi
OS Lite (Trixie or Bookworm) 64-bit. Pi Zero 2 W is the slowest target;
keep source videos ≤ 1080p30 H.264 for smooth playback.

## Conventions

- Run as root in the service (kiosk device, no SSH, no network services).
- No docs files (`*.md`) created without explicit ask — README and
  docs/BUILDING.md are the only intentional ones.
- Version bumps: patch tag for CI-only fixes, bump feature-level for
  player/script changes. Keep old releases around unless explicitly asked
  to delete.

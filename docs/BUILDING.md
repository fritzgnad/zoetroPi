# Building the ZoetroPi image

You have two options.

## A. Automatic — GitHub Actions (recommended)

1. Fork the repo (or clone your own copy) on GitHub.
2. Push a tag starting with `v`, e.g.:
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```
3. The `Build ZoetroPi image` workflow runs `pi-gen` against Raspberry Pi OS
   Lite (Bookworm) with our custom stage, then attaches the resulting
   `zoetropi-*.img.xz` to a GitHub Release.

You can also trigger the workflow manually from the **Actions** tab using
*Run workflow*.

The build takes roughly 25–40 minutes on the free GitHub runner.

## B. Local — run pi-gen by hand

You need a Debian or Ubuntu machine (or WSL). pi-gen does not run natively on
macOS or Windows.

```bash
sudo apt-get install -y coreutils quilt parted qemu-user-static debootstrap \
    zerofree zip dosfstools libarchive-tools libcap2-bin grep rsync xz-utils \
    file git curl bc qemu-utils kpartx gpg pigz xxd arch-test

git clone https://github.com/fritzgnad/zoetroPi.git
(cd zoetroPi && ./pi-gen/sync-stage-files.sh)

git clone https://github.com/RPi-Distro/pi-gen.git
cd pi-gen
ln -s ../zoetroPi/pi-gen/stage-zoetropi ./stage-zoetropi

cat > config <<'EOF'
IMG_NAME=zoetropi
RELEASE=bookworm
TARGET_HOSTNAME=zoetropi
FIRST_USER_NAME=pi
FIRST_USER_PASS=zoetropi
ENABLE_SSH=0
STAGE_LIST="stage0 stage1 stage2 ./stage-zoetropi"
EOF

sudo ./build.sh
```

The finished image lands in `deploy/` as `*.img.xz`.

## Customising

- Put `.mp4` files in `pi-gen/stage-zoetropi/00-install/files/` and copy
  them into `/opt/zoetropi/videos/` from `00-run.sh` to ship videos in the
  image.
- Change the default user/password in the pi-gen `config` (or the
  `with:` block of the workflow) before publishing.

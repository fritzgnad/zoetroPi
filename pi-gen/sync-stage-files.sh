#!/bin/bash
# Copy the repo's scripts/systemd/config into the pi-gen custom stage's
# files/ directory so pi-gen has a self-contained stage to build from.
#
# Run this once before invoking pi-gen (or before the GitHub Actions
# workflow does). Re-running is safe.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$REPO_ROOT/pi-gen/stage-zoetropi/00-install/files"

mkdir -p "$DEST"
cp "$REPO_ROOT/scripts/zoetropi-play.sh"      "$DEST/zoetropi-play.sh"
cp "$REPO_ROOT/config/mpv.conf"               "$DEST/mpv.conf"
cp "$REPO_ROOT/systemd/zoetropi.service"      "$DEST/zoetropi.service"

echo "Synced stage files into $DEST"

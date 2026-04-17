#!/bin/bash -e
# Copy the previous stage's rootfs so this stage can add packages and files
# on top of Raspberry Pi OS Lite.
if [ ! -d "${ROOTFS_DIR}" ]; then
    copy_previous
fi

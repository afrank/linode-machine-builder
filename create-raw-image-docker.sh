#!/bin/bash

ENABLE_CLOUDINIT=1
ENABLE_LISH=1

# DISTRO=debian
# RELEASE=sid
# IMGSIZE=2G

# DISTRO=ubuntu
# RELEASE=jammy
# IMGSIZE=4G # ubuntu needs a bigger base rootfs

if [[ ! "$USER" = "root" ]]; then
    echo "Error: This command must be run with superuser privileges. Sorry."
    exit 2
fi

BUILD_TAG=$(date +%m%d%H%M)
IMG=machine-builder:$BUILD_TAG

time docker build -t $IMG .

time docker run \
    -e DISTRO=$DISTRO \
    -e RELEASE=$RELEASE \
    -e IMGSIZE=$IMGSIZE \
    -e ENABLE_CLOUDINIT=$ENABLE_CLOUDINIT \
    -e ENABLE_LISH=$ENABLE_LISH \
    --privileged \
    -v /dev:/dev \
    -e OUTDIR=/output \
    -v $(pwd):/output \
    $IMG

if [[ "$SUDO_USER" ]]; then
    chown $SUDO_USER *.img.gz *id_rsa*
fi

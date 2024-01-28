#!/bin/bash

if [[ ! "$USER" = "root" ]]; then
    echo "Error: This command must be run with superuser privileges. Sorry."
    exit 2
fi

BUILD_TAG=$(date +%m%d%H%M)
IMG=machine-builder:$BUILD_TAG

time docker build -t $IMG .

time docker run \
    #-e DISTRO=debian \
    #-e RELEASE=sid \
    #-e IMGSIZE=2G \
    -e DISTRO=ubuntu \
    -e RELEASE=jammy \
    -e IMGSIZE=4G \
    -e ENABLE_CLOUDINIT=1 \
    -e ENABLE_LISH=1 \
    --privileged \
    -v /dev:/dev \
    -e OUTDIR=/output \
    -v $(pwd):/output \
    $IMG

if [[ "$SUDO_USER" ]]; then
    chown $SUDO_USER *.img.gz *id_rsa*
fi

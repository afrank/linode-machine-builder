#!/bin/bash

if [[ ! "$USER" = "root" ]]; then
    echo "Error: This command must be run with superuser privileges. Sorry."
    exit 2
fi

BUILD_TAG=$(date +%m%d%H%M)
IMG=machine-builder:$BUILD_TAG

time docker build -t $IMG .

time docker run \
    --privileged \
    -e OUTDIR=/output \
    -v /dev:/dev \
    -v $(pwd):/output \
    $IMG

if [[ "$SUDO_USER" ]]; then
    chown $SUDO_USER *.img.gz *id_rsa*
fi

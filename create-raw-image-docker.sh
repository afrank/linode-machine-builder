#!/bin/bash

ENABLE_CLOUDINIT=1
ENABLE_LISH=1

# a note about EFI support:
# setting BOOT_MODE to efi will enable EFI support.
# however, since Linode doesn't currently support EFI,
# grub-pc will be used in the final image. This can
# be overriden by setting OVERRIDE_EFI_MODE=0
BOOT_MODE=efi

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
    -e BOOT_MODE=$BOOT_MODE \
    --privileged \
    -v /dev:/dev \
    -e OUTDIR=/output \
    -v $(pwd):/output \
    $IMG

if [[ "$SUDO_USER" ]]; then
    chown $SUDO_USER *.img.gz *id_rsa*
fi

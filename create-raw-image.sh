#!/bin/bash

if [[ ! "$USER" = "root" && ! "$HOME" = "/root" ]]; then
    echo "Error: This command must be run with superuser privileges. Sorry."
    exit 2
fi

LABEL=${LABEL:-linode1}
DISTRO=${DISTRO:-debian}

# Enabling console access is a nice convenience but 
# also gives the cloud provider an extra way to get 
# a shell on your server. Use with caution!
ENABLE_LISH=${ENABLE_LISH:-1}

# cloud-init is involved in resizing the rootfs on first boot, 
# so if you don't use it, you just need to run this on first boot:
# growpart /dev/sda 2 && resize2fs /dev/sda2
ENABLE_CLOUDINIT=${ENABLE_CLOUDINIT:-1}

OUTDIR=${OUTDIR:-./}

# These are the packages installed during debootstrap. Extra packages 
# installed after the base system is built can be added with the
# comma-delimited environment variable EXTRA_INCLUDES
INCLUDES="openssh-server,init,iproute2,xz-utils,wget,parted,curl,dosfstools,vim,python3,initramfs-tools,ca-certificates,dbus,cloud-utils,cloud-initramfs-growroot,zstd,locales-all,libpam-systemd,dialog,apt-utils,iputils-ping"

IMGSIZE=${IMGSIZE:-2G}
FILE=$OUTDIR/base.img

NETWORK_MATCH="en*"

MNT_DIR=$(mktemp -d)

[[ ${ENABLE_CLOUDINIT:-0} -eq 1 ]] && EXTRA_INCLUDES="$EXTRA_INCLUDES,cloud-init"

case $DISTRO in
    debian)
        MIRROR=${MIRROR:-"http://ftp.us.debian.org/debian"}
        RELEASE=${RELEASE:-"sid"}
        BOOT_PKG="linux-image-amd64"
    ;;
    ubuntu)
        MIRROR=${MIRROR:-"http://mirrors.linode.com/ubuntu"}
        RELEASE=${RELEASE:-"jammy"}
        BOOT_PKG="linux-image-generic"
        COMPONENTS="--components=main,restricted,universe,multiverse"
    ;;
    *) exit 1;;
esac

# legacy boot mode
BOOT_PATH=/boot 
BOOT_FS=ext4
BOOT_ARGS="sync 0       2"
BOOT_PKG="$BOOT_PKG grub-pc"
BOOT_TARGET="--target=i386-pc"

[[ -d $(dirname $FILE) ]] || mkdir -p $(dirname $FILE)

if [[ -e $FILE ]]; then
    echo "$FILE already exists. Removing."
    rm -f $FILE
fi

cleanup() {
    chroot $MNT_DIR umount /proc/ /sys/ /dev/ $BOOT_PATH && sleep 5
    umount $MNT_DIR && sleep 3
    rm -r $MNT_DIR
    if [[ "$DISK" ]]; then
        losetup -d $DISK && sleep 3
    fi
}

fail() {
    cleanup
    echo "FAILED: $1"
    exit 1
}

cancel() {
    fail "CTRL-C detected"
}

trap cancel INT

if [ ! -f $FILE ]; then
    echo "Creating $FILE"
    truncate -s $IMGSIZE $FILE
fi

DISK=$(losetup -f)

losetup $DISK $FILE || exit 2

parted -a optimal --script -- $DISK \
  mklabel msdos \
  unit mib \
  mkpart primary 1 256 \
  set 1 boot on \
  mkpart primary 256 -1

sleep 3

mkfs.${BOOT_FS} ${DISK}p1 || fail "cannot create $BOOT_PATH $BOOT_FS"
mkfs.ext4 -q ${DISK}p2 || fail "cannot create / ext4"
mount ${DISK}p2 $MNT_DIR || fail "cannot mount /"

debootstrap --variant=minbase $COMPONENTS --include=$INCLUDES $RELEASE $MNT_DIR $MIRROR || fail "cannot install $RELEASE into $DISK"

cat <<EOF > $MNT_DIR/etc/fstab
/dev/sda1 $BOOT_PATH           ${BOOT_FS}    ${BOOT_ARGS}
/dev/sda2 /                   ext4    errors=remount-ro 0       1
EOF

echo $LABEL > $MNT_DIR/etc/hostname

cat <<EOF > $MNT_DIR/etc/hosts
127.0.0.1     localhost $LABEL
::1     localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

[[ -d $MNT_DIR/etc/systemd/network ]] || mkdir -p $MNT_DIR/etc/systemd/network

cat <<EOF > $MNT_DIR/etc/systemd/network/en.network
[Match]
Name=$NETWORK_MATCH

[Network]
DHCP=yes
EOF

mkdir -p ${MNT_DIR}${BOOT_PATH}

mount --bind /dev/ $MNT_DIR/dev || fail "cannot bind /dev"
chroot $MNT_DIR mount -t $BOOT_FS ${DISK}p1 $BOOT_PATH || fail "cannot mount $BOOT_PATH"

chroot $MNT_DIR mount -t proc none /proc || fail "cannot mount /proc"
chroot $MNT_DIR mount -t sysfs none /sys || fail "cannot mount /sys"

export DEBIAN_FRONTEND=noninteractive
export LANG=C
chroot $MNT_DIR apt install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages -q $BOOT_PKG ${EXTRA_INCLUDES//,/ } || fail "cannot install $BOOT_PKG ${EXTRA_INCLUDES//,/ }"

if [[ ${ENABLE_LISH:-0} -eq 1 ]]; then
    echo 'GRUB_GFXPAYLOAD_LINUX=text' >> $MNT_DIR/etc/default/grub
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="console=ttyS0,115200n81"' >> $MNT_DIR/etc/default/grub
    echo 'GRUB_TERMINAL=serial' >> $MNT_DIR/etc/default/grub
    echo 'GRUB_SERIAL_COMMAND="serial --speed=19200 --unit=0 --word=8 --parity=no --stop=1"' >> $MNT_DIR/etc/default/grub
fi

echo 'GRUB_DISABLE_OS_PROBER=true' >> $MNT_DIR/etc/default/grub

chroot $MNT_DIR grub-install $BOOT_TARGET $DISK || fail "cannot install grub"
chroot $MNT_DIR update-grub || fail "cannot update grub"
chroot $MNT_DIR apt-get clean || fail "unable to clean apt cache"
chroot $MNT_DIR systemctl enable systemd-networkd || fail "failed to enable systemd-networkd"
chroot $MNT_DIR systemctl enable ssh || fail "failed to enable sshd"
[[ ${ENABLE_LISH:-0} -eq 1 ]] && chroot $MNT_DIR systemctl enable serial-getty@ttyS0.service

sed -i "s|${DISK}p1|/dev/sda1|g" $MNT_DIR/boot/grub/grub.cfg
sed -i "s|${DISK}p2|/dev/sda2|g" $MNT_DIR/boot/grub/grub.cfg

mkdir -vp $MNT_DIR/root/.ssh
chmod 750 $MNT_DIR/root/.ssh
if [[ ! -e $OUTDIR/$LABEL-id_rsa.pub ]]; then
    ssh-keygen -t rsa -b 4096 -f $OUTDIR/$LABEL-id_rsa -q -N "" || exit 2
    [[ "$SUDO_USER" ]] && chown $SUDO_USER $OUTDIR/$LABEL-id_rsa $OUTDIR/$LABEL-id_rsa.pub
fi

cat $OUTDIR/$LABEL-id_rsa.pub > $MNT_DIR/root/.ssh/authorized_keys
chmod 640 $MNT_DIR/root/.ssh/authorized_keys

truncate -s0 $MNT_DIR/etc/machine-id

cleanup

[[ -e $FILE.gz ]] && rm -f $FILE.gz
gzip $FILE

FILE=$FILE.gz

if [[ "$SUDO_USER" ]]; then
    chown $SUDO_USER:$SUDO_USER $FILE
fi


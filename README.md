# linode-machine-builder

This is a set of tools for building machine images that can be uploaded to Linode and run as direct-disk VMs.

# How to use

You will need to have docker installed, and you will need sudo access. This should work on mac but I haven't tested it yet. You will also need linode-cli with working API access.

## Building the image

Tl;dr:
```
# sudo DISTRO=debian RELEASE=sid IMGSIZE=2G ./create-raw-image-docker.sh
sudo DISTRO=ubuntu RELEASE=jammy IMGSIZE=4G ./create-raw-image-docker.sh
REGION=us-sea ./upload-raw-image.sh base.img.gz my-machine-image-1
image_id=$(linode-cli images list --label my-machine-image-1 --json | jq -r '.[0].id')
REGION=us-sea ./create-raw-linode.sh $image_id my-ubuntu-machine-1
```

The image is built with `create-raw-image.sh`. This tool requires the following dependencies: `debootstrap dosfstools parted openssh-client` and must be run with superuser privileges. The following environment variables are supported for configuration:
* LABEL -- image label
* DISTRO -- debian|ubuntu. Default: debian
* RELEASE -- version of the debian/ubuntu distro you want (eg. jammy, sid, bookworm, etc). Default: sid
* IMGSIZE -- This is 2G by default, but some images (like ubuntu) have a larger minbase and need a larger base image. Default: 2G
* BOOT_MODE -- efi|legacy; This dictates which boot mode is supported via partition scheme and grub setup. Note: Linode supports legacy. Default: efi
* OVERRIDE_EFI_MODE -- Since Linode only supports legacy, you can use this in combination with BOOT_MODE to build an efi-supported image which also supports legacy and works in Linode. Default: 1
* ENABLE_CLOUDINIT -- installs cloud-init into the base image. If you don't use cloud-init, you may need to resize your rootfs by hand. See below.
* ENABLE_LISH -- Enable console redirection for supporting LISH. This is useful for out-of-band console access, but it does create an extra security consideration, so use with caution.
* OUTFILE -- The name of the final gzipped image we produce. Default: base.img.gz
* PUBKEY -- The name of the pubkey to use for the root authorized_keys. This is relative to the docker CWD. If not present, one will attempt to be generated. Default: $LABEL-id_rsa.pub

### Building the image with Docker

The preferred method of running `create-raw-image.sh` is via docker by using `create-raw-image-docker.sh`. The requirements are docker support, and you must be able to run a privileged container as superuser. The reason privileged superuser is required is the process creates a loopback device in /dev.

### Resizing your rootfs

When you create a linode from your image, the disk you get will be larger than the image you created, so some process needs to resize your image to fit your disk. cloud-init will handle this if you choose to install it. If you don't install it, you can still perform this operation on your live disk (as long as you're increasing the size, not decreasing). The first time your vm boots, you can login and run these commands to resize it. Make note of your rootfs partition, if you selected legacy, it's sda2, if you selected efi, it's sda3:
```
growpart /dev/sda 3
resize2fs /dev/sda3
```

## Uploading the image

The image can be uploaded to Linode as a machine image using the `upload-raw-image.sh` command. Before you run this, you should run `linode-cli linodes list` to make sure linode-cli is working and your Personal Access Token has been set up. If not, follow the directions produced by linode-cli to set it up. The command will poll the image status until it's available.

```
REGION=us-sea ./create-raw-linode.com base.img.gz my-test-image
```

## Creating a linode

Creating a direct-disk linode isn't as straightforward as creating a normal linode. You have to create the linode non-Booted, then edit its config, then boot it. We perform these steps with the `create-raw-linode.sh` script. As with the upload script, this script requires working linode-cli access. You will need the image id of the image you uploaded in the previous step. After booting the linode, the command will ping it until it becomes available. Optionally you can specify which plan to use, with g6-nanode-1 as the default.

```
image_id=$(linode-cli images list --label my-test-image --json | jq -r '.[0].id')

REGION=us-sea ./create-raw-linode.sh $image_id my-linode-1 [g6-nanode-1]
```


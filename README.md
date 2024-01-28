# linode-machine-builder

This is a set of tools for building machine images that can be uploaded to Linode and run as direct-disk VMs.

# How to use

You will need to have docker installed, and you will need sudo access. This should work on mac but I haven't tested it yet. You will also need linode-cli with working API access.

Tl;dr:
```
# sudo DISTRO=debian RELEASE=sid IMGSIZE=2G ./create-raw-image-docker.sh
sudo DISTRO=ubuntu RELEASE=jammy IMGSIZE=4G ./create-raw-image-docker.sh
./upload-raw-image.sh base.img.gz us-sea my-machine-image-1
image_id=$(linode-cli images list --label my-machine-image-1 --json | jq -r '.[0].id')
./create-raw-linode.sh $image_id my-ubuntu-machine-1
```

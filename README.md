# linode-machine-builder

This is a set of tools for building machine images that can be uploaded to Linode and run as direct-disk VMs.

# How to use

You will need to have docker installed, and you will need sudo access. This should work on mac but I haven't tested it yet. You will also need linode-cli with working API access.

Tl;dr:
```
sudo ./create-raw-image-docker.sh
./upload-raw-image.sh base.img.gz
./create-raw-linode.sh private/<imgid> raw-test-1
```

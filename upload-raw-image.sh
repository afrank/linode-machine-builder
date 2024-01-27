#!/bin/bash

filename=$1
region=${2:-us-sea}
label=$3

if [[ ! -e $filename || ! "$filename" =~ ".img.gz" ]]; then
    echo "Usage: $0 <filename> [region] [label]"
    echo "Filename must end with .img.gz"
    exit 2
fi

[[ "$label" ]] || label=${filename//.img.gz}-$(date +%F)

linode-cli image-upload --label $label --region $region $filename || exit 2

sleep 2

image_id=$(linode-cli images list --label $label --json | jq -r '.[0].id')

if [[ ! "$image_id" ]]; then
    echo "Failed to find Image"
    exit 2
fi

timeout=20
echo "Waiting for $image_id to become available..."
cur=0
while [ 1 ]; do
    stat=$(linode-cli images list --label $label --json | jq -r '.[0].status')
    [[ "$stat" = "available" ]] && break
    echo $(date) "--" Status:$stat
    sleep 3
    ((cur++))
    if (( cur > timeout )); then
        echo "Failure: Timeout reached waiting for $image_id to become available."
        exit 2
    fi
done

echo Done.

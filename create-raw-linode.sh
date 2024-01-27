#!/bin/bash

#machine_image=private/23563388 # sid-base-2024-01-27
machine_image=$1
label=$2
region=${3:-us-sea}
plan=${4:-g6-nanode-1}

if [[ ! "$machine_image" || ! "$label" ]]; then
    echo "Usage: $0 <machine_image> <label> [region] [plan]"
    exit 2
fi

tmpfile=$(mktemp)

# create the linode not booted
linode-cli linodes create \
  --backups_enabled false \
  --booted false \
  --image $machine_image \
  --label $label \
  --private_ip false \
  --region us-sea \
  --root_pass thiswillnevergetset \
  --json \
  --type $plan | grep $label > $tmpfile

linode_id=$(jq -r '.[0].id' $tmpfile)
ipaddr=$(jq -r '.[0].ipv4[0]' $tmpfile)

if [[ ! "$linode_id" ]]; then
    echo "Linode not found"
    cat $tmpfile
    rm -f $tmpfile
    exit 2
fi

rm -f $tmpfile

config_id=$(linode-cli linodes configs-list $linode_id --json | jq -r '.[0].id')

linode-cli linodes config-update --kernel linode/direct-disk $linode_id $config_id >/dev/null

linode-cli linodes boot $linode_id

timeout=100
echo "Created $label ($linode_id) IPv4 $ipaddr -- waiting for networking..."
while [ 1 ]; do
    if ping -c1 -w1 $ipaddr >/dev/null 2>&1; then
        break
    fi
    ((cur++))
    if (( cur > timeout )); then
        echo "Timeout reached waiting for $ipaddr to wake up"
	exit 2
    fi
    sleep 2
done

echo "$label ($linode_id) is ready at $ipaddr"

#root@linode1:~# growpart /dev/sda 2
#root@linode1:~# resize2fs /dev/sda2

#!/bin/bash
vmids=( 103 104 105 ) # VMIDs of VMs to delete
for vmid in "${vmids[@]}"
do
    status=$(qm status "$vmid")
    if [ "$status" = "status: running" ]; then
      qm stop $vmid
    fi
    qm destroy $vmid
done
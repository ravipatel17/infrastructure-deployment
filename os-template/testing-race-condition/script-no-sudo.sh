#! /bin/bash

VMID=8201
STORAGE=local-lvm
IMAGE=noble-server-cloudimg-amd64.img

set -euxo pipefail

rm -f "$IMAGE"
wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

qemu-img resize "$IMAGE" 8G

# Install guest agent into the image before Proxmox ever boots it.
# Requires: apt install libguestfs-tools
virt-customize -a "$IMAGE" \
  --install qemu-guest-agent \
  --run-command 'systemctl enable qemu-guest-agent' \
  --run-command 'systemctl enable ssh'

# Recreate template VM
qm stop "$VMID" || true
qm destroy "$VMID" --purge || true

qm create "$VMID" \
  --name "ubuntu-noble-template" \
  --ostype l26 \
  --memory 1024 \
  --balloon 0 \
  --agent 1 \
  --bios ovmf \
  --machine q35 \
  --efidisk0 "$STORAGE:0,pre-enrolled-keys=0" \
  --cpu host \
  --socket 1 \
  --cores 1 \
  --vga serial0 \
  --serial0 socket \
  --net0 virtio,bridge=vmbr0

qm importdisk "$VMID" "$IMAGE" "$STORAGE"

# Use scsi0 as the OS disk
qm set "$VMID" \
  --scsihw virtio-scsi-pci \
  --scsi0 "$STORAGE:vm-$VMID-disk-1,discard=on"

qm set "$VMID" --boot order=scsi0

# Cloud-init drive
qm set "$VMID" --scsi1 "$STORAGE:cloudinit"

cat << EOF > /var/lib/vz/snippets/ubuntu.yaml
#cloud-config
package_update: true
runcmd:
  - systemctl enable --now qemu-guest-agent
  - systemctl enable --now ssh
EOF

qm set "$VMID" --cicustom "vendor=local:snippets/ubuntu.yaml"
qm set "$VMID" --tags ubuntu-template,noble,cloudinit
qm set "$VMID" --ciuser "$USER"
qm set "$VMID" --sshkeys ~/.ssh/authorized_keys
qm set "$VMID" --ipconfig0 ip=dhcp

qm template "$VMID"
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.25.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = true
  username = var.proxmox_user
  password = var.proxmox_password
  ssh {
    agent    = true
    username = "root"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_nodes" {
  count     = 3
  name      = "k3s-node-${count.index + 1}"
  node_name = "pcloud"          # Replace with your Proxmox node name
  vm_id     = 103 + count.index # Adjust this range to avoid collisions

  clone {
    datastore_id = "local-lvm" # Adjust to your storage
    vm_id        = 8200        # ID of your cloud-init template
    full         = true
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 8192
  }

  network_device {
    bridge = "vmbr0"
  }
  #the disk is created during the creation of the template.
  # disk {
  #   datastore_id = "local-lvm"
  #   size         = 8
  #   interface    = "scsi0"
  # }

  disk {
    datastore_id = "local-lvm"
    interface    = "virtio0"
    size         = 20
    discard      = "on"
    iothread     = true
    file_format  = "raw"
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
  }
}

resource "local_file" "ansible_inventory" {
  filename   = "${path.module}/../ansible/inventory.ini"
  depends_on = [proxmox_virtual_environment_vm.k3s_nodes]
  content    = <<EOT
[k3s_nodes]
%{for vm in proxmox_virtual_environment_vm.k3s_nodes~}
${vm.name} ansible_host=${vm.ipv4_addresses[1][0]}
%{endfor~}

[k3s_nodes:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=../id_rsa
host_key_checking = False
EOT
}

output "k3s_nodes_info" {
  depends_on = [proxmox_virtual_environment_vm.k3s_nodes]
  value = {
    for vm in proxmox_virtual_environment_vm.k3s_nodes :
    vm.name => vm.ipv4_addresses[1][0]
  }
  description = "Map of VM names to their IP addresses"
}

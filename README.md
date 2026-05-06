# Infrastructure Deployment

This repository contains Terraform infrastructure-as-code, Ansible automation, and helper scripts for deploying a small k3s cluster on Proxmox.

Terraform is the main entry point. It provisions the virtual machines and automatically generates the Ansible inventory file used by the playbook.

## Repository layout

```text
.
├── ansible/
│   ├── inventory.example.ini
│   ├── playbook.yml
│   └── roles/
├── terraform/
│   ├── main.tf
│   ├── vars.tf
│   └── terraform.tfvars.example
├── start-cluster-script.sh
└── delete-vms.sh
```

## Prerequisites

Install the following on the machine where you will run the deployment:

- Terraform
- Ansible
- SSH access to the provisioned Ubuntu VMs
- Access to your Proxmox node or cluster
- A Proxmox cloud-init template VM

## Configure Terraform variables

Create your local Terraform variables file from the example:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` and set your Proxmox details:

```hcl
proxmox_endpoint = "https://YOUR-PROXMOX-HOST:8006/api2/json"
proxmox_user     = "root@pam"
proxmox_password = "YOUR_PROXMOX_PASSWORD"
```

The `terraform.tfvars` file is ignored by Git because it may contain secrets.

## Review Terraform VM settings

Before applying, review `terraform/main.tf`.

The current Terraform configuration provisions three VMs named:

- `k3s-node-1`
- `k3s-node-2`
- `k3s-node-3`

It also uses Proxmox-specific values such as:

- Proxmox node name
- VM ID range
- Cloud-init template VM ID
- Storage datastore
- Network bridge
- CPU and memory settings

Update those values for your Proxmox environment before running Terraform.

## Deploy the infrastructure

Initialize Terraform:

```bash
terraform -chdir="./terraform" init
```

Apply the Terraform configuration using the variables file:

```bash
terraform -chdir="./terraform" apply -var-file="terraform.tfvars"
```

Terraform will provision the VMs and automatically generate:

```text
ansible/inventory.ini
```

This generated inventory file contains the VM IP addresses returned by Proxmox.

## About the Ansible inventory

The real inventory file is generated automatically by Terraform:

```text
ansible/inventory.ini
```

Do not commit this file. It may contain environment-specific IP addresses or SSH settings.

A safe example inventory is provided here:

```text
ansible/inventory.example.ini
```

Use the example only for documentation or manual testing.

## Run the Ansible playbook

After Terraform finishes and `ansible/inventory.ini` has been generated, run:

```bash
ansible-playbook -i ./ansible/inventory.ini ./ansible/playbook.yml
```

This configures the first node as the k3s master and the remaining nodes as k3s workers.

## Optional helper script

You can also use the helper script:

```bash
chmod +x start-cluster-script.sh
./start-cluster-script.sh
```

The script should run Terraform first, then Ansible.

If needed, update it to reference the Terraform variables file and the correct playbook filename:

```bash
#!/bin/bash

terraform -chdir="./terraform" apply -auto-approve -var-file="terraform.tfvars"
ansible-playbook -i ./ansible/inventory.ini ./ansible/playbook.yml
```

## Remove generated inventory files from Git

The generated inventory file should not be tracked by Git.

Remove any accidental `.inventory.ini` file:

```bash
rm -f .inventory.ini
rm -f ansible/.inventory.ini
```

Remove the generated Ansible inventory file if it exists locally:

```bash
rm -f ansible/inventory.ini
```

If any of these files were already committed, stop tracking them:

```bash
git rm --cached .inventory.ini 2>/dev/null || true
git rm --cached ansible/.inventory.ini 2>/dev/null || true
git rm --cached ansible/inventory.ini 2>/dev/null || true
```

Add the generated inventory files to `.gitignore`:

```gitignore
# Generated Ansible inventory
ansible/inventory.ini
.inventory.ini
ansible/.inventory.ini
```

Commit the cleanup:

```bash
git add .gitignore ansible/inventory.example.ini terraform/terraform.tfvars.example
git commit -m "Add example config files and ignore generated inventory"
```

## Destroy VMs

The repository includes a `delete-vms.sh` helper script.

Review the VM IDs in the script before running it, then execute:

```bash
chmod +x delete-vms.sh
./delete-vms.sh
```

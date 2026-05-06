#!/bin/bash
terraform -chdir="./terraform" apply  -auto-approve
ansible-playbook -i ./ansible/inventory.ini ./ansible/playbook.yaml
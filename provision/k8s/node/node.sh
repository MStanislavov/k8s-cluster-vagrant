#!/bin/bash
source /vagrant/environment.properties
source /vagrant/provision/config/error_handling.sh

COMPONENT=$1

echo -e "${ORANGE}${COMPONENT} provisioning ${YELLOW}START${ORANGE}${NC}"

# Set up a K8S worker node and join it to the cluster

sudo apt-get install nfs-common -y

set -euxo pipefail

config_path="/vagrant/configs"
sudo mkdir -p ~/.kube
sudo cp -i $config_path/config ~/.kube/
/bin/bash $config_path/join.sh -v

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
NODENAME=$(hostname -s)
kubectl label node $(hostname -s) node-role.kubernetes.io/worker=worker
EOF

echo "Waiting 20 seconds for the worker node to register with the cluster..."
sleep 20

echo -e "${ORANGE}${COMPONENT} provisioning ${GREEN}DONE${ORANGE}${NC}"
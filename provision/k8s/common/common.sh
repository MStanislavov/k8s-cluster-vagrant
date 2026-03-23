#!/bin/bash
# Common setup shared by all K8S nodes (control plane and workers)

source /vagrant/environment.properties
source /vagrant/provision/config/error_handling.sh

DNS_SERVERS=$1
KUBERNETES_VERSION=$2
CRIO_VERSION=$3
OS=$4
ENVIRONMENT=$5
COMPONENT=$6

echo -e "${ORANGE}${COMPONENT} provisioning ${YELLOW}START${ORANGE}${NC}"

set -euxo pipefail

# Disable firewall
sudo service ufw stop
sudo ufw disable

# Configure DNS servers
sudo mkdir /etc/systemd/resolved.conf.d/
cat <<EOF | sudo tee /etc/systemd/resolved.conf.d/dns_servers.conf
[Resolve]
DNS=${DNS_SERVERS}
EOF

sudo systemctl restart systemd-resolved

# Disable swap
sudo swapoff -a

# Ensure swap stays off after reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
sudo apt-get update -y

# Install CRI-O Runtime
sudo bash /vagrant/provision/k8s/common/install-crio.sh "${OS}" "${CRIO_VERSION}" "${ENVIRONMENT}"

# Install Kubernetes
sudo bash /vagrant/provision/k8s/common/install-k8s.sh "${KUBERNETES_VERSION}" "${ENVIRONMENT}"

echo -e "${ORANGE}${COMPONENT} provisioning ${GREEN}DONE${ORANGE}${NC}"
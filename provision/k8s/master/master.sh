#!/bin/bash
source /vagrant/environment.properties
source /vagrant/provision/config/error_handling.sh

CONTROL_IP=$1
POD_CIDR=$2
SERVICE_CIDR=$3
COMPONENT=$4

echo -e "${ORANGE}${COMPONENT} provisioning ${YELLOW}START${ORANGE}${NC}"

# Set up the K8S control plane (master) node

set -euxo pipefail

NODENAME=$(hostname -s)

sudo kubeadm config images pull

echo "Preflight Check Passed: Downloaded All Required Images"

sudo kubeadm init --apiserver-advertise-address=$CONTROL_IP --apiserver-cert-extra-sans=$CONTROL_IP --pod-network-cidr=$POD_CIDR --service-cidr=$SERVICE_CIDR --node-name "$NODENAME" --ignore-preflight-errors Swap

mkdir -p /home/vagrant/k8s
mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Save configs to the shared /vagrant directory.
# On re-runs, clear any existing configs before writing new ones.

config_path="/vagrant/configs"

if [ -d $config_path ]; then
  rm -f $config_path/*
else
  mkdir -p $config_path
fi

cp -i /etc/kubernetes/admin.conf $config_path/config
touch $config_path/join.sh
chmod +x $config_path/join.sh

kubeadm token create --print-join-command > $config_path/join.sh

# Install Calico Network Plugin

curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml -O

kubectl apply -f calico.yaml

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF

# Install Metrics Server
kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml

# Install Helm
sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh --version v3.5.2

sudo -u vagrant helm repo update

# Remove the control-plane taint so pods can be scheduled on the master node
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-

# Install custom components asynchronously (Reloader, etc.)
sudo mkdir -p /opt/logs/components
nohup bash /vagrant/provision/k8s/components/install-components.sh > /opt/logs/components/components-provisioning.log 2>&1 &

# Expand the NodePort range to allow all ports (0-65535)
sudo sed -i '20i \ \ \ \ - --service-node-port-range=0-65535' /etc/kubernetes/manifests/kube-apiserver.yaml
sudo service kubelet restart

# Install NFS server to provide shared storage across nodes
sudo apt-get install nfs-kernel-server -y
sudo apt-get install nfs-common -y

sudo mkdir /var/nfs_share_dir
sudo cp /vagrant/provision/config/nfs/exports /etc
sudo exportfs -a
sudo systemctl start nfs-kernel-server
sudo systemctl enable nfs-kernel-server

echo -e "${ORANGE}${COMPONENT} provisioning ${GREEN}DONE${ORANGE}${NC}"
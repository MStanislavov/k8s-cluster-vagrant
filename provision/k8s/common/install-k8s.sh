#!/bin/bash
source /vagrant/environment.properties

echo -e "${PURPLE}K8S Node configuration provisioning ${YELLOW}START${PURPLE}${NC}"

KUBERNETES_VERSION=$1
ENVIRONMENT=$2

# Update and install dependencies
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

# Download and add the GPG key for the Kubernetes APT repository
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes APT repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package listings
sudo apt-get update -y

# Install K8S packages and pin their versions to prevent unintended upgrades
sudo apt-get install -y kubelet kubectl kubeadm
sudo apt-mark hold kubelet kubeadm kubectl

# Install jq for JSON processing
sudo apt-get install -y jq

# Configure kubelet to advertise the correct node IP (eth1 on the private network)
local_ip="$(ip --json a s | jq -r '.[] | if .ifname == "eth1" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
${ENVIRONMENT}
EOF

echo -e "${PURPLE}K8S Node configuration provisioning ${GREEN}DONE${PURPLE}${NC}"
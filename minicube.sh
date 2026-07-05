#!/bin/bash

# Minikube Installation Script for Ubuntu 24.04
# Includes installation of golang-go, cri-dockerd, crictl, CNI plugins, and Minikube

set -e

echo "Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

echo "Installing dependencies..."
sudo apt-get install -y apt-transport-https curl wget conntrack socat gnupg2 software-properties-common golang-go

# Install Docker (required container runtime)
echo "Installing Docker..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker



# Install cri-ctl (Docker CRI compatibility)
echo "Installing crictl..."
VERSION="v1.32.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz

# Install cri-dockerd (Docker CRI compatibility)
echo "Installing cri-dockerd (Docker CRI compatibility)..."
git clone https://github.com/Mirantis/cri-dockerd.git
cd cri-dockerd
mkdir bin

# Build cri-dockerd using Go
echo "Building cri-dockerd..."
go build -o bin/cri-dockerd

#Move cri-dockerd to /usr/local/bin and set up systemd service
sudo cp bin/cri-dockerd /usr/local/bin/
sudo cp packaging/systemd/* /etc/systemd/system/
sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
sudo systemctl daemon-reload
sudo systemctl enable cri-docker
sudo systemctl start cri-docker

# Clean up cri-dockerd repository
cd ..
rm -rf cri-dockerd

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/


# # Install crictl (required by Kubernetes 1.24+)
# echo "Installing crictl..."
# VERSION="v1.31.0"
# wget https://github.com/kubernetes-sigs/cri-tools/releases/download/${VERSION}/crictl-${VERSION}-linux-amd64.tar.gz
# sudo tar -xvf crictl-${VERSION}-linux-amd64.tar.gz -C /usr/local/bin
# sudo chmod +x /usr/local/bin/crictl

# Install CNI Plugins
echo "Installing CNI plugins..."
CNI_VERSION="v1.2.0"
wget https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -xvf cni-plugins-linux-amd64-${CNI_VERSION}.tgz -C /opt/cni/bin

# Verify installations
echo "Verifying installations..."
crictl --version
ls /opt/cni/bin
cri-dockerd --version

# Install Minikube
echo "Installing Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Add current user to Docker group
echo "Configuring Docker permissions for non-root user..."
CURRENT_USER=$(whoami)
sudo usermod -aG docker $CURRENT_USER
newgrp docker <<EOF

# Start Minikube with cri-dockerd
echo "Starting Minikube with cri-dockerd..."
minikube start --driver=none

EOF

# Verify Installation
echo "Verifying Minikube installation..."
minikube version
kubectl version --client
minikube status

echo "Minikube installation completed successfully!"

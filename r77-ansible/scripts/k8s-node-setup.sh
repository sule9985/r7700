#!/bin/bash


# Step 1: Update the system
echo "Updating system packages..."
apt update && apt upgrade -y

# Step 2: Configure /etc/hosts
echo "Configuring /etc/hosts..."
cat <<EOF > /etc/hosts
127.0.0.1   localhost
127.0.1.1   $HOSTNAME

# Kubernetes cluster nodes
192.168.100.11  k8s-cp1
192.168.100.12  k8s-cp2
192.168.100.13  k8s-cp3
192.168.100.14  k8s-worker4
192.168.100.15  k8s-worker5
192.168.100.16  k8s-worker6
EOF

# Step 3: Disable swap
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Verify swap is disabled
echo "Verifying swap is disabled..."
free -h
swapon --show

# Step 4: Install and configure containerd
echo "Installing containerd..."

# Load necessary kernel modules
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Configure sysctl params
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Verify kernel modules and sysctl settings
echo "Verifying kernel modules and sysctl settings..."
lsmod | grep -E "br_netfilter|overlay"
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

# Install containerd
apt-get update
apt-get install -y containerd

# Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Enable SystemdCgroup in containerd config
echo "Configuring containerd to use SystemdCgroup..."
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Set CNI binary path in containerd config
echo "Setting CNI binary path to /opt/cni/bin..."
if grep -q '^\s*bin_dir\s*=' /etc/containerd/config.toml; then
    # If bin_dir already exists, update it
    sed -i 's|^\s*bin_dir\s*=.*|      bin_dir = "/opt/cni/bin"|' /etc/containerd/config.toml
else
    # If bin_dir doesn't exist, add it after the [plugins."io.containerd.grpc.v1.cri".cni] section
    sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.cni\]/a\      bin_dir = "/opt/cni/bin"' /etc/containerd/config.toml
fi

# Restart containerd
systemctl restart containerd
systemctl enable containerd
echo "Containerd installed and configured."

# Step 5: Install Kubernetes tools
echo "Installing Kubernetes tools (kubeadm, kubelet, kubectl)..."

# Install prerequisites
apt install -y apt-transport-https ca-certificates curl gpg

# Add Kubernetes apt key and repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' > /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes tools
apt update
apt install -y kubelet kubeadm kubectl

# Hold Kubernetes packages at current version
apt-mark hold kubelet kubeadm kubectl

# Verify kubeadm version
echo "Verifying kubeadm version..."
kubeadm version
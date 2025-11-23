#!/bin/bash
# LXC Container Network and SSH Setup Script
# Run this script on the Proxmox host to configure a new LXC container
# Usage: ./setup-lxc-network.sh <container_id> <ip_address> <hostname>

set -e

CONTAINER_ID="${1:-140}"
CONTAINER_IP="${2:-192.168.100.40}"
CONTAINER_HOSTNAME="${3:-grafana-stack}"
GATEWAY="192.168.100.1"

echo "========================================="
echo "Setting up LXC Container $CONTAINER_ID"
echo "IP: $CONTAINER_IP"
echo "Hostname: $CONTAINER_HOSTNAME"
echo "========================================="
echo

# Check if container exists and is running
if ! pct status "$CONTAINER_ID" | grep -q "running"; then
    echo "Error: Container $CONTAINER_ID is not running"
    exit 1
fi

echo "Step 1: Configuring network interface..."
pct exec "$CONTAINER_ID" -- bash -c "cat > /etc/network/interfaces << 'EOF'
# Loopback interface
auto lo
iface lo inet loopback

# Primary network interface
auto eth0
iface eth0 inet static
    address $CONTAINER_IP
    netmask 255.255.255.0
    gateway $GATEWAY
    dns-nameservers 8.8.8.8 8.8.4.4
EOF"

echo "Step 2: Bringing up network interface..."
pct exec "$CONTAINER_ID" -- ip link set eth0 up
pct exec "$CONTAINER_ID" -- ifup eth0

echo "Step 3: Setting hostname..."
pct exec "$CONTAINER_ID" -- bash -c "echo '$CONTAINER_HOSTNAME' > /etc/hostname"
pct exec "$CONTAINER_ID" -- hostname "$CONTAINER_HOSTNAME"

echo "Step 4: Updating /etc/hosts..."
pct exec "$CONTAINER_ID" -- bash -c "cat > /etc/hosts << 'EOF'
127.0.0.1       localhost
$CONTAINER_IP    $CONTAINER_HOSTNAME

::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF"

echo "Step 5: Updating package cache..."
pct exec "$CONTAINER_ID" -- apt-get update -qq

echo "Step 6: Installing SSH server and essential packages..."
pct exec "$CONTAINER_ID" -- apt-get install -y openssh-server python3 sudo curl wget locales

echo "Step 7: Configuring locale..."
pct exec "$CONTAINER_ID" -- bash -c 'echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen'
pct exec "$CONTAINER_ID" -- locale-gen en_US.UTF-8
pct exec "$CONTAINER_ID" -- update-locale LANG=en_US.UTF-8

echo "Step 8: Enabling and starting SSH service..."
pct exec "$CONTAINER_ID" -- systemctl enable ssh
pct exec "$CONTAINER_ID" -- systemctl start ssh

echo "Step 9: Creating .ssh directory..."
pct exec "$CONTAINER_ID" -- mkdir -p /root/.ssh
pct exec "$CONTAINER_ID" -- chmod 700 /root/.ssh

echo
echo "========================================="
echo "Network Configuration:"
echo "========================================="
pct exec "$CONTAINER_ID" -- ip addr show eth0

echo
echo "========================================="
echo "SSH Service Status:"
echo "========================================="
pct exec "$CONTAINER_ID" -- systemctl status ssh --no-pager || true

echo
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo
echo "To add your SSH public key, run ONE of these commands:"
echo
echo "Option 1 - From your local machine:"
echo "  cat ~/.ssh/vm-deb13.pub | ssh root@$CONTAINER_IP 'cat >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys'"
echo
echo "Option 2 - From Proxmox host:"
echo "  cat ~/.ssh/vm-deb13.pub | pct exec $CONTAINER_ID -- bash -c 'cat > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys'"
echo
echo "Option 3 - If you have the key on Proxmox host:"
echo "  pct push $CONTAINER_ID /path/to/vm-deb13.pub /root/.ssh/authorized_keys"
echo "  pct exec $CONTAINER_ID -- chmod 600 /root/.ssh/authorized_keys"
echo
echo "Then test SSH connection:"
echo "  ssh -i ~/.ssh/vm-deb13 root@$CONTAINER_IP"
echo
echo "========================================="

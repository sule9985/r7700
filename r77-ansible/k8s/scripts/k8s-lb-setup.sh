#!/bin/bash

# Variables
TCP_CONF_DIR="/etc/nginx/tcpconf.d"
K8S_PROXY_CONF="/etc/nginx/tcpconf.d/k8s.conf"
NGINX_CONF="/etc/nginx/nginx.conf"

# Install Nginx
echo "[INFO] Installing Nginx..."
sudo apt update && sudo apt -y install nginx libnginx-mod-stream

# Create folder for TCP configs
echo "[INFO] Creating directory $TCP_CONF_DIR..."
sudo mkdir -p $TCP_CONF_DIR

# Create k8s.conf file
echo "[INFO] Creating Kubernetes proxy configuration..."
sudo tee $K8S_PROXY_CONF > /dev/null <<EOF
stream {
    upstream k8s {
        server 192.168.100.11:6443;
        server 192.168.100.12:6443;
        server 192.168.100.13:6443;
    }

    server {
        listen 6443;
        proxy_pass k8s;
    }
}
EOF

# Ensure the Nginx main config includes the new TCP config directory
if ! grep -q "include $TCP_CONF_DIR/*;" "$NGINX_CONF"; then
    echo "[INFO] Adding TCP config include to $NGINX_CONF..."
    echo "include $TCP_CONF_DIR/*;" | sudo tee -a "$NGINX_CONF"
fi

# Test Nginx configuration
echo "[INFO] Testing Nginx configuration..."
sudo nginx -t

# Reload Nginx
echo "[INFO] Reloading Nginx..."
sudo systemctl reload nginx

echo "[SUCCESS] Nginx proxy setup completed!"
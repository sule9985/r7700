# Grafana Monitoring Component

Terraform component for deploying a dedicated Grafana monitoring server with Prometheus and Loki on Proxmox.

## Overview

This component provisions a VM that serves as a centralized monitoring and observability platform for:
- **Kubernetes cluster** on Proxmox (local)
- **AWS VMs** and services
- **Digital Ocean VMs** and services
- **Any infrastructure** accessible via network

### Stack Components

- **Grafana** - Unified visualization and dashboarding
- **Prometheus** - Metrics collection, storage, and alerting
- **Loki** - Log aggregation and querying (lightweight alternative to ELK)

## VM Specifications

| Component | Value |
|-----------|-------|
| Hostname | grafana |
| IP Address | 192.168.100.21 |
| VMID | 121 |
| CPU | 4 cores |
| Memory | 4GB |
| Disk | 60GB |
| OS | Debian 13 (cloud-init) |

## Prerequisites

1. **Proxmox VE** with API access
2. **Debian 13 template** (VMID 998 or 999) with:
   - cloud-init support
   - qemu-guest-agent installed
3. **SSH public key** at `r77-tf/keys/vm-deb13.pub`
4. **Network access** to:
   - Proxmox node (192.168.100.4)
   - Kubernetes API (192.168.100.10:6443)
   - Target monitoring endpoints (AWS, DO, etc.)

## Quick Start

### 1. Configure Credentials

```bash
cd r77-tf/components/grafana

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your Proxmox credentials
vim terraform.tfvars
```

**Or use environment variables (recommended):**

```bash
export TF_VAR_proxmox_api_url="https://192.168.100.4:8006"
export TF_VAR_proxmox_api_token_id="root@pam!terraform=your-secret-token"
export TF_VAR_proxmox_tls_insecure=true
```

### 2. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy Grafana VM
terraform apply

# View outputs
terraform output
```

**Expected output:**
```
grafana_web_ui = "http://192.168.100.21:3000"
grafana_ssh_command = "ssh a1@192.168.100.21"
prometheus_ui = "http://192.168.100.21:9090"
```

### 3. Configure with Ansible

After VM deployment, configure the monitoring stack with Ansible:

```bash
cd ../../../r77-ansible

# Test connectivity
ansible grafana -m ping

# Install and configure Grafana stack
ansible-playbook grafana-setup.yml
```

This will install:
- Docker and Docker Compose
- Grafana (port 3000)
- Prometheus (port 9090)
- Loki (port 3100)

### 4. Access Grafana

```bash
# Add to /etc/hosts (optional, for hostname access)
echo "192.168.100.21    grafana.local" | sudo tee -a /etc/hosts

# Open in browser
open http://192.168.100.21:3000
```

**Default credentials:**
- Username: `admin`
- Password: `admin` (change on first login!)

## Configuration

### Customizing VM Specifications

Edit `variables.tf` or override in `terraform.tfvars`:

```hcl
# Increase resources for heavy workloads
grafana_vm_id = 121
grafana_hostname = "grafana"
grafana_ip = "192.168.100.21"

# Infrastructure settings
proxmox_node = "pve"
storage_name = "local-zfs"
template_id = 998
```

### Modifying Resource Allocation

To change CPU/memory/disk, edit `main.tf`:

```hcl
module "grafana" {
  # ...

  cores  = 6      # Increase to 6 cores
  memory = 8192   # Increase to 8GB

  disks = [{
    size = 100    # Increase to 100GB
    # ...
  }]
}
```

Then apply changes:
```bash
terraform apply
```

## Monitoring Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Monitored Infrastructure                                     │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ K8s Cluster  │  │   AWS VMs    │  │  DO VMs      │      │
│  │ (Proxmox)    │  │              │  │              │      │
│  └───────┬──────┘  └───────┬──────┘  └───────┬──────┘      │
│          │                 │                 │              │
│          │ metrics/logs    │ metrics/logs    │ metrics/logs │
│          └─────────────────┴─────────────────┘              │
│                             │                                │
└─────────────────────────────┼────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Grafana Server (192.168.100.21)                             │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Prometheus   │  │    Loki      │  │   Grafana    │      │
│  │ :9090        │  │    :3100     │  │    :3000     │      │
│  │              │  │              │  │              │      │
│  │ • Metrics    │  │ • Logs       │  │ • Dashboards │      │
│  │ • Alerts     │  │ • Queries    │  │ • Alerts     │      │
│  │ • Scraping   │  │ • Retention  │  │ • Users      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Exporters and Agents

**For Kubernetes:**
- **kube-state-metrics** - Cluster state metrics
- **node-exporter** - Node-level metrics
- **Promtail** - Log shipping to Loki

**For AWS/DO VMs:**
- **node-exporter** - System metrics (CPU, memory, disk, network)
- **Promtail** - Log shipping to Loki

**For Custom Apps:**
- **Application metrics** - Expose /metrics endpoint
- **Custom logs** - Ship to Loki

## Common Operations

### SSH Access

```bash
# Direct SSH
ssh a1@192.168.100.21

# Check Docker containers
ssh a1@192.168.100.21 "sudo docker ps"

# View Grafana logs
ssh a1@192.168.100.21 "sudo docker logs grafana"
```

### Accessing Services

```bash
# Grafana UI
http://192.168.100.21:3000

# Prometheus UI
http://192.168.100.21:9090

# Prometheus targets
http://192.168.100.21:9090/targets

# Loki (API only, query via Grafana)
http://192.168.100.21:3100/ready
```

### Backup and Restore

```bash
# Backup Grafana dashboards and config
ssh a1@192.168.100.21
sudo docker exec grafana grafana-cli admin export-dashboards

# Backup Prometheus data
sudo tar czf prometheus-backup-$(date +%Y%m%d).tar.gz /var/lib/docker/volumes/prometheus-data

# Copy to local machine
scp a1@192.168.100.21:prometheus-backup-*.tar.gz ./
```

### Updating the Stack

```bash
cd r77-ansible
ansible-playbook grafana-setup.yml --tags update
```

## Monitoring Kubernetes

After setup, configure Prometheus to scrape Kubernetes metrics:

```yaml
# In prometheus.yml
scrape_configs:
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
      - role: endpoints
        api_server: 'https://192.168.100.10:6443'
        tls_config:
          ca_file: /etc/prometheus/k8s-ca.crt
        bearer_token_file: /etc/prometheus/k8s-token
```

Import Kubernetes dashboards in Grafana:
- Dashboard ID 8588 - Kubernetes Deployment Stats
- Dashboard ID 15757 - Kubernetes Views Global
- Dashboard ID 15758 - Kubernetes Views Namespaces

## Monitoring AWS/DO VMs

Install node-exporter on target VMs:

```bash
# On AWS/DO VMs
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xzf node_exporter-1.7.0.linux-amd64.tar.gz
sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
sudo systemctl enable --now node-exporter
```

Add to Prometheus configuration:

```yaml
# In prometheus.yml
scrape_configs:
  - job_name: 'aws-vms'
    static_configs:
      - targets:
          - 'aws-vm-1:9100'
          - 'aws-vm-2:9100'

  - job_name: 'do-vms'
    static_configs:
      - targets:
          - 'do-vm-1:9100'
          - 'do-vm-2:9100'
```

## Troubleshooting

### VM Won't Start

```bash
# Check VM status on Proxmox
qm status 121

# View VM console
qm terminal 121

# Check cloud-init logs
ssh a1@192.168.100.21 "sudo cloud-init status --long"
```

### Can't Access Grafana UI

```bash
# Check if Docker is running
ssh a1@192.168.100.21 "sudo systemctl status docker"

# Check if Grafana container is running
ssh a1@192.168.100.21 "sudo docker ps | grep grafana"

# Check firewall
ssh a1@192.168.100.21 "sudo ufw status"

# Test connectivity
curl http://192.168.100.21:3000
```

### Prometheus Not Scraping Targets

```bash
# Check Prometheus targets
http://192.168.100.21:9090/targets

# Check Prometheus logs
ssh a1@192.168.100.21 "sudo docker logs prometheus"

# Verify network connectivity
ssh a1@192.168.100.21 "curl -v http://target:9100/metrics"
```

### High Resource Usage

```bash
# Check resource usage
ssh a1@192.168.100.21 "htop"

# Check disk usage
ssh a1@192.168.100.21 "df -h"

# Adjust Prometheus retention (default 15d)
# Edit prometheus.yml:
# --storage.tsdb.retention.time=7d
```

## Security Considerations

### Firewall Configuration

The Ansible playbook configures UFW to allow:
- Port 22 (SSH)
- Port 3000 (Grafana)
- Port 9090 (Prometheus)
- Port 3100 (Loki)

**For production:**
- Restrict access to specific IPs
- Use reverse proxy with SSL/TLS
- Enable Grafana authentication (OAuth, LDAP)

### Authentication

**Change default Grafana password immediately:**

```bash
# Via UI: Admin → Profile → Change Password

# Via CLI
ssh a1@192.168.100.21
sudo docker exec -it grafana grafana-cli admin reset-admin-password newpassword
```

### TLS/SSL

For production, configure reverse proxy with Let's Encrypt:

```bash
# Install nginx
sudo apt install nginx certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d grafana.yourdomain.com

# Configure nginx to proxy to :3000
```

## Cleanup

### Destroy Grafana VM

```bash
cd r77-tf/components/grafana
terraform destroy
```

### Remove from Ansible Inventory

Edit `r77-ansible/inventory.yml` and remove the grafana group.

## References

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Prometheus Exporters](https://prometheus.io/docs/instrumenting/exporters/)

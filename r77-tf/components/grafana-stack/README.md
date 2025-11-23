# Grafana Stack LXC Container

Complete monitoring stack in a single LXC container for Proxmox infrastructure monitoring.

## Components

- **Grafana** (v12.3.0) - Visualization and dashboarding on port 3000
- **Prometheus** (v3.7.3) - Metrics collection and storage on port 9090
- **Loki** (v3.6.0) - Log aggregation on port 3100
- **AlertManager** (v0.29.0) - Alert handling on port 9093
- **Proxmox PVE Exporter** (latest) - Proxmox metrics exporter on port 9221

## Container Specifications

- **VMID**: 140
- **Hostname**: grafana-stack
- **IP Address**: 192.168.100.40/24
- **OS**: Debian 13 (LXC container)
- **Resources**: 4 CPU cores, 8GB RAM, 2GB swap, 50GB disk
- **Type**: Unprivileged LXC container

## Resource Sizing Rationale

| Service | RAM Usage | CPU Usage | Storage |
|---------|-----------|-----------|---------|
| Grafana | ~512 MB | 1 core | ~100 MB |
| Prometheus | 2-4 GB | 2 cores | 20-30 GB (15-day retention) |
| Loki | 1-2 GB | 1 core | 10-15 GB (7-day retention) |
| AlertManager | ~256 MB | 0.5 core | ~100 MB |
| PVE Exporter | ~128 MB | 0.5 core | ~10 MB |
| System | ~512 MB | - | 2-3 GB |
| **Total** | **~8 GB** | **4 cores** | **~50 GB** |

## Prerequisites

1. **Proxmox VE** with API access configured
2. **Debian 13 LXC template** downloaded to Proxmox:
   ```bash
   # On Proxmox host
   pveam update
   pveam download local debian-13-standard_13.1-2_amd64.tar.zst
   ```
3. **SSH public key** at `r77-tf/keys/vm-deb13.pub`

## Deployment

### 1. Configure Terraform Variables

```bash
cd r77-tf/components/grafana-stack
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox credentials
```

Or use environment variables:
```bash
export TF_VAR_proxmox_api_url="https://proxmox:8006"
export TF_VAR_proxmox_api_token_id="user@pam!terraform=secret"
export TF_VAR_proxmox_tls_insecure=true
```

### 2. Deploy LXC Container

```bash
terraform init
terraform plan
terraform apply
```

### 3. Verify Container

```bash
terraform output
# Shows: container_id, IPs, URLs for all services
```

### 4. Configure Monitoring Stack with Ansible

```bash
cd ../../../r77-ansible
ansible-playbook grafana-stack-setup.yml
```

## Access URLs

After deployment and Ansible configuration:

- **Grafana**: http://192.168.100.40:3000 (admin/admin)
- **Prometheus**: http://192.168.100.40:9090
- **AlertManager**: http://192.168.100.40:9093
- **Loki**: http://192.168.100.40:3100 (API only)
- **PVE Exporter**: http://192.168.100.40:9221/metrics

## SSH Access

```bash
ssh root@192.168.100.40
```

## Integration with JMeter

The Prometheus instance will be configured to scrape metrics from:
- JMeter server (192.168.100.23:9270) - Load test metrics
- Proxmox nodes - Infrastructure metrics
- Other exporters as configured

## Maintenance

### Start/Stop Container
```bash
# On Proxmox host
pct start 140
pct stop 140
pct status 140
```

### Check Service Status
```bash
ssh root@192.168.100.40
systemctl status grafana-server
systemctl status prometheus
systemctl status loki
systemctl status alertmanager
systemctl status prometheus-pve-exporter
```

## Terraform Destruction

```bash
terraform destroy
```

## Notes

- Container is configured with `start_on_boot = true` for automatic startup
- No nesting required (monitoring services run natively, not in Docker)
- Unprivileged container for better security
- All services run as systemd units

# Proxmox Monitoring Quick Setup

Quick reference for setting up Proxmox monitoring with Grafana stack.

## Prerequisites

- ✅ Grafana stack deployed on LXC (192.168.100.40)
- ✅ Proxmox VE host accessible (192.168.100.4:8006)
- ✅ SSH access to both systems

## 5-Minute Setup

### 1. Create Monitoring User on Proxmox

SSH to Proxmox host and run:

```bash
ssh root@192.168.100.4

# Create user with read-only access
pveum user add monitoring@pve --comment "Prometheus monitoring"
pveum acl modify / --user monitoring@pve --role PVEAuditor

# Create API token (save the output!)
pveum user token add monitoring@pve exporter --privsep 0
```

**Save the token value** from the output!

### 2. Configure PVE Exporter on grafana-stack

SSH to grafana-stack and edit config:

```bash
ssh root@192.168.100.40

cat > /etc/prometheus-pve-exporter/pve.yml << 'EOF'
default:
  user: monitoring@pve
  token_name: "exporter"
  token_value: "PASTE-YOUR-TOKEN-HERE"
  verify_ssl: false

pve1:
  user: monitoring@pve
  token_name: "exporter"
  token_value: "PASTE-YOUR-TOKEN-HERE"
  verify_ssl: false
  target: https://192.168.100.4:8006
EOF
```

**Important**: Replace `PASTE-YOUR-TOKEN-HERE` with your actual token!

### 3. Start PVE Exporter

```bash
systemctl start prometheus-pve-exporter
systemctl status prometheus-pve-exporter

# Verify metrics
curl http://localhost:9221/metrics | grep pve_up
# Should show: pve_up{target="192.168.100.4:8006"} 1.0
```

### 4. Verify Prometheus is Scraping

Open browser: http://192.168.100.40:9090/targets

Look for `proxmox` job - should show **UP** status.

### 5. Import Grafana Dashboard

1. Open: http://192.168.100.40:3000
2. Login: `admin` / `admin` (change password)
3. Click "+" → "Import Dashboard"
4. Enter ID: `10347`
5. Select "Prometheus" datasource
6. Click "Import"

**Done!** You should now see your Proxmox metrics in Grafana.

## Quick Verification Checklist

```bash
# On grafana-stack (192.168.100.40)
□ PVE Exporter running:    systemctl status prometheus-pve-exporter
□ Metrics available:        curl -s http://localhost:9221/metrics | head
□ Prometheus scraping:      curl -s http://localhost:9090/api/v1/targets | grep proxmox
□ Grafana accessible:       curl -s http://localhost:3000/api/health
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `pve_up` shows 0 | Check Proxmox IP, verify token, check firewall |
| Authentication failed | Verify token in config, check user has PVEAuditor role |
| No data in Grafana | Check Prometheus targets page, verify datasource |
| Connection refused | Ensure Proxmox is accessible: `curl -k https://192.168.100.4:8006` |

## Key Metrics to Monitor

```promql
# Is Proxmox reachable?
pve_up

# CPU usage (percentage)
pve_cpu_usage_ratio * 100

# Memory usage (percentage)
(pve_memory_usage_bytes / pve_memory_size_bytes) * 100

# Disk usage
pve_disk_usage_bytes / pve_disk_size_bytes * 100

# Number of running VMs
count(pve_guest_info{status="running"})
```

## Access URLs

- **Grafana**: http://192.168.100.40:3000
- **Prometheus**: http://192.168.100.40:9090
- **PVE Exporter**: http://192.168.100.40:9221/metrics
- **Proxmox**: https://192.168.100.4:8006

## Recommended Dashboards

| ID | Name | Description |
|----|------|-------------|
| 10347 | Proxmox VE | Most comprehensive, recommended |
| 10048 | Proxmox Summary | Simpler overview |
| 15356 | Proxmox Multi-Server | For multiple hosts |

## Next Steps

After basic setup:
1. ✅ Set up alerts (see PROXMOX_MONITORING_SETUP.md)
2. ✅ Monitor JMeter metrics (already configured)
3. ✅ Add more Proxmox hosts if needed
4. ✅ Configure AlertManager notifications (email/Slack)
5. ✅ Export dashboards as JSON for backup

## Complete Guide

For detailed explanations, advanced configuration, and troubleshooting, see:
- [PROXMOX_MONITORING_SETUP.md](PROXMOX_MONITORING_SETUP.md)

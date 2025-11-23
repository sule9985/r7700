# Proxmox Monitoring Setup Guide

This guide shows you how to configure the Grafana stack to monitor your Proxmox VE server.

## Overview

The monitoring setup consists of:
1. **Proxmox PVE Exporter** (on grafana-stack LXC) - Collects metrics from Proxmox API
2. **Prometheus** (on grafana-stack LXC) - Scrapes and stores metrics
3. **Grafana** (on grafana-stack LXC) - Visualizes the data

## Architecture

```
┌─────────────────────┐
│  Proxmox VE Host    │
│  192.168.100.4:8006 │
│                     │
│  API Token/User     │
└──────────┬──────────┘
           │ HTTPS API calls
           │ (read-only)
           ▼
┌─────────────────────────────────┐
│  grafana-stack LXC              │
│  192.168.100.40                 │
│                                 │
│  ┌───────────────────────────┐ │
│  │ PVE Exporter :9221        │ │
│  │ (pulls from Proxmox API)  │ │
│  └──────────┬────────────────┘ │
│             │ metrics           │
│             ▼                   │
│  ┌───────────────────────────┐ │
│  │ Prometheus :9090          │ │
│  │ (scrapes every 15s)       │ │
│  └──────────┬────────────────┘ │
│             │ queries           │
│             ▼                   │
│  ┌───────────────────────────┐ │
│  │ Grafana :3000             │ │
│  │ (dashboards)              │ │
│  └───────────────────────────┘ │
└─────────────────────────────────┘
```

## Step 1: Create Monitoring User on Proxmox

You need to create a read-only user on your Proxmox host that the PVE Exporter will use to collect metrics.

### SSH to Proxmox Host

```bash
ssh root@192.168.100.4
```

### Create User and Assign Permissions

```bash
# Create a monitoring user (PVE realm)
pveum user add monitoring@pve --comment "Prometheus monitoring user"

# Assign read-only auditor role to the user
# This gives read-only access to all resources
pveum acl modify / --user monitoring@pve --role PVEAuditor

# Set a password for the user
pveum passwd monitoring@pve
# Enter password when prompted (e.g., "monit0ring123")
```

### Alternative: Use API Token (Recommended)

API tokens are more secure than passwords and don't require storing credentials.

```bash
# Create user first
pveum user add monitoring@pve --comment "Prometheus monitoring user"

# Assign auditor role
pveum acl modify / --user monitoring@pve --role PVEAuditor

# Create API token (with privilege separation disabled for simplicity)
pveum user token add monitoring@pve exporter --privsep 0

# Output will show:
# ┌──────────────┬──────────────────────────────────────┐
# │ key          │ value                                │
# ╞══════════════╪══════════════════════════════════════╡
# │ full-tokenid │ monitoring@pve!exporter              │
# ├──────────────┼──────────────────────────────────────┤
# │ info         │ {"privsep":"0"}                      │
# ├──────────────┼──────────────────────────────────────┤
# │ value        │ xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx │
# └──────────────┴──────────────────────────────────────┘

# IMPORTANT: Save the token value - you'll need it in the next step!
```

### Verify User Creation

```bash
pveum user list

# Should show:
# monitoring@pve

pveum acl list

# Should show:
# monitoring@pve with PVEAuditor role
```

## Step 2: Configure PVE Exporter on grafana-stack

Now configure the exporter on your grafana-stack LXC container.

### SSH to grafana-stack

```bash
ssh root@192.168.100.40
```

### Edit PVE Exporter Configuration

```bash
nano /etc/prometheus-pve-exporter/pve.yml
```

### Configuration Option A: Using API Token (Recommended)

Replace the file content with:

```yaml
default:
  user: monitoring@pve
  token_name: "exporter"
  token_value: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Replace with YOUR token
  verify_ssl: false
```

**Important**: Replace `token_value` with the actual token you got from Step 1.

### Configuration Option B: Using Password

```yaml
default:
  user: monitoring@pve
  password: "monit0ring123"  # Replace with your password
  verify_ssl: false
```

### Add Proxmox Host Target (Important!)

The exporter needs to know which Proxmox host to monitor. Add this section:

```bash
nano /etc/prometheus-pve-exporter/pve.yml
```

Complete configuration should look like:

```yaml
default:
  user: monitoring@pve
  token_name: "exporter"
  token_value: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  verify_ssl: false

# Target Proxmox hosts
pve1:
  user: monitoring@pve
  token_name: "exporter"
  token_value: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  verify_ssl: false
  target: https://192.168.100.4:8006
```

**Note**: The `target` parameter tells the exporter where to connect to Proxmox API.

## Step 3: Start PVE Exporter Service

```bash
# Start the service
systemctl start prometheus-pve-exporter

# Check status
systemctl status prometheus-pve-exporter

# Should show "active (running)"
```

### Verify Exporter is Working

```bash
# Check if metrics are being collected
curl -s http://localhost:9221/metrics | head -20

# Should see Prometheus metrics like:
# pve_up{target="192.168.100.4:8006"} 1.0
# pve_version_info{...} 1.0
# pve_node_info{...} 1.0
# pve_cpu_usage_ratio{...} 0.05
# pve_memory_usage_bytes{...} 12345678
```

### Troubleshooting

If the service fails to start:

```bash
# Check logs
journalctl -u prometheus-pve-exporter -n 50 --no-pager

# Common issues:
# 1. Wrong token/password → Check credentials
# 2. Connection refused → Check Proxmox host IP and port
# 3. Permission denied → Verify user has PVEAuditor role
# 4. SSL errors → Ensure verify_ssl: false is set
```

## Step 4: Verify Prometheus is Scraping

Prometheus should already be configured to scrape the PVE exporter (installed by the setup script).

### Check Prometheus Configuration

```bash
cat /etc/prometheus/prometheus.yml
```

Look for the Proxmox job:

```yaml
scrape_configs:
  # Proxmox PVE Exporter
  - job_name: 'proxmox'
    static_configs:
      - targets: ['localhost:9221']
        labels:
          service: 'proxmox-pve'
          instance: 'pve-host'
```

### Verify in Prometheus UI

1. Open browser: http://192.168.100.40:9090
2. Go to Status → Targets
3. Look for `proxmox` job
4. Should show `UP` status with endpoint `localhost:9221`

### Query Metrics

In Prometheus, try these queries:

```promql
# Check if Proxmox is reachable
pve_up

# CPU usage
pve_cpu_usage_ratio

# Memory usage
pve_memory_usage_bytes

# VM status
pve_guest_info

# Node status
pve_node_info
```

## Step 5: Import Grafana Dashboard

Now visualize the metrics in Grafana.

### Access Grafana

1. Open browser: http://192.168.100.40:3000
2. Login with default credentials:
   - Username: `admin`
   - Password: `admin`
3. Change password when prompted

### Import Official Proxmox Dashboard

1. Click "+" → "Import Dashboard" (or use Dashboards → Import)
2. Enter Dashboard ID: `10347`
3. Click "Load"
4. Select "Prometheus" as the data source
5. Click "Import"

This will give you a comprehensive dashboard showing:
- CPU, Memory, Disk usage
- Network traffic
- VM/Container status
- Storage usage
- Cluster health

### Alternative Dashboards

Try these other dashboard IDs:

- **10347** - Proxmox VE (most popular, comprehensive)
- **10048** - Proxmox Summary (simpler view)
- **15356** - Proxmox VE Multi-Server (if you have multiple hosts)

### Create Custom Dashboard (Optional)

You can create custom panels with queries like:

```promql
# CPU usage percentage
100 - (avg by (instance) (irate(pve_cpu_usage_limit[5m])) * 100)

# Memory usage percentage
(pve_memory_usage_bytes / pve_memory_size_bytes) * 100

# Disk usage
100 - ((pve_disk_size_bytes - pve_disk_usage_bytes) / pve_disk_size_bytes * 100)

# Running VMs count
count(pve_guest_info{type="qemu", status="running"})

# Running LXC containers count
count(pve_guest_info{type="lxc", status="running"})
```

## Step 6: Configure Alerts (Optional)

Create alert rules for Proxmox monitoring.

### Create Alert Rules File

```bash
nano /etc/prometheus/rules/proxmox.yml
```

Add these alert rules:

```yaml
groups:
  - name: proxmox_alerts
    interval: 30s
    rules:
      # Proxmox host down
      - alert: ProxmoxHostDown
        expr: pve_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Proxmox host {{ $labels.instance }} is down"
          description: "Cannot reach Proxmox API on {{ $labels.instance }}"

      # High CPU usage
      - alert: ProxmoxHighCPU
        expr: pve_cpu_usage_ratio > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is {{ $value | humanizePercentage }} on {{ $labels.instance }}"

      # High memory usage
      - alert: ProxmoxHighMemory
        expr: (pve_memory_usage_bytes / pve_memory_size_bytes) > 0.90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is {{ $value | humanizePercentage }} on {{ $labels.instance }}"

      # Disk space low
      - alert: ProxmoxLowDiskSpace
        expr: (pve_disk_usage_bytes / pve_disk_size_bytes) > 0.85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on {{ $labels.storage }}"
          description: "Disk usage is {{ $value | humanizePercentage }} on {{ $labels.storage }}"

      # VM down
      - alert: ProxmoxVMDown
        expr: pve_guest_info{status!="running"} == 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "VM {{ $labels.name }} is not running"
          description: "VM {{ $labels.name }} (VMID {{ $labels.id }}) status: {{ $labels.status }}"
```

### Reload Prometheus Configuration

```bash
# Reload without restart (using --web.enable-lifecycle flag)
curl -X POST http://localhost:9090/-/reload

# Or restart service
systemctl restart prometheus
```

### Verify Alerts in Prometheus

1. Open http://192.168.100.40:9090/alerts
2. You should see your new alert rules
3. Alerts will show in Grafana and AlertManager when triggered

## Step 7: Test the Setup

### Verify End-to-End Monitoring

1. **Check PVE Exporter**: http://192.168.100.40:9221/metrics
   - Should show metrics with `pve_` prefix

2. **Check Prometheus Targets**: http://192.168.100.40:9090/targets
   - Proxmox job should be `UP`

3. **Check Grafana Dashboard**: http://192.168.100.40:3000
   - Dashboard 10347 should show live data

### Trigger a Test Alert (Optional)

```bash
# On Proxmox host, create a high CPU load temporarily
stress --cpu 8 --timeout 300

# Watch alert fire in Prometheus alerts page
# Alert will appear in Grafana after 5 minutes
```

## Maintenance

### Update PVE Exporter

```bash
pip3 install --upgrade prometheus-pve-exporter --break-system-packages
systemctl restart prometheus-pve-exporter
```

### Rotate API Token

```bash
# On Proxmox host
pveum user token remove monitoring@pve exporter
pveum user token add monitoring@pve exporter --privsep 0

# Update token in /etc/prometheus-pve-exporter/pve.yml
# Restart exporter
systemctl restart prometheus-pve-exporter
```

### Check Metrics Retention

Prometheus is configured with 15-day retention. Adjust if needed:

```bash
nano /etc/systemd/system/prometheus.service

# Change --storage.tsdb.retention.time=15d to desired value
systemctl daemon-reload
systemctl restart prometheus
```

## Summary

You now have:
- ✅ Proxmox metrics being collected by PVE Exporter
- ✅ Prometheus scraping and storing metrics
- ✅ Grafana dashboard visualizing Proxmox state
- ✅ Optional alert rules for critical events

**Access URLs:**
- Grafana: http://192.168.100.40:3000
- Prometheus: http://192.168.100.40:9090
- PVE Exporter: http://192.168.100.40:9221/metrics

## Troubleshooting Guide

### Problem: PVE Exporter shows "pve_up 0"

**Cause**: Cannot connect to Proxmox API

**Solutions**:
1. Check Proxmox host IP: `ping 192.168.100.4`
2. Check Proxmox web UI: https://192.168.100.4:8006
3. Verify credentials in `/etc/prometheus-pve-exporter/pve.yml`
4. Check firewall on Proxmox: `iptables -L -n | grep 8006`

### Problem: "Authentication failed" in logs

**Cause**: Wrong credentials or insufficient permissions

**Solutions**:
1. Test credentials on Proxmox web UI
2. Verify user has PVEAuditor role: `pveum acl list`
3. If using token, check it's not expired: `pveum user token list monitoring@pve`
4. Recreate token if needed

### Problem: No data in Grafana dashboard

**Cause**: Prometheus not scraping or data not flowing

**Solutions**:
1. Check Prometheus targets: http://192.168.100.40:9090/targets
2. Verify PVE exporter is running: `systemctl status prometheus-pve-exporter`
3. Test metrics endpoint: `curl http://localhost:9221/metrics`
4. Check Prometheus logs: `journalctl -u prometheus -f`
5. Verify datasource in Grafana is configured correctly

### Problem: SSL/TLS errors

**Cause**: Self-signed certificate on Proxmox

**Solution**: Ensure `verify_ssl: false` in PVE exporter config

### Problem: Metrics show "stale" or "no data"

**Cause**: Scrape interval mismatch or exporter failure

**Solutions**:
1. Check Prometheus scrape interval (default 15s)
2. Restart PVE exporter: `systemctl restart prometheus-pve-exporter`
3. Check system time sync: `timedatectl status`

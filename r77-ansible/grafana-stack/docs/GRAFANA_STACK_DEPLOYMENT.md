# Grafana Stack Deployment Guide

Complete monitoring solution for Proxmox infrastructure with JMeter integration.

## Overview

This deploys a comprehensive monitoring stack in a single LXC container:

| Service | Purpose | Port | URL |
|---------|---------|------|-----|
| **Grafana** | Visualization & dashboards | 3000 | http://192.168.100.40:3000 |
| **Prometheus** | Metrics collection & storage | 9090 | http://192.168.100.40:9090 |
| **Loki** | Log aggregation | 3100 | http://192.168.100.40:3100 |
| **AlertManager** | Alert routing & notification | 9093 | http://192.168.100.40:9093 |
| **PVE Exporter** | Proxmox metrics | 9221 | http://192.168.100.40:9221/metrics |

## Container Specifications

- **VMID**: 140
- **Hostname**: grafana-stack
- **IP**: 192.168.100.40/24
- **OS**: Debian 13 LXC
- **Resources**: 4 CPU, 8GB RAM, 2GB swap, 50GB disk

## Prerequisites

### 1. Proxmox Template

Download the Debian 13 LXC template on your Proxmox host:

```bash
# SSH to Proxmox host
ssh root@192.168.100.1

# Download template
pveam update
pveam download local debian-13-standard_13.1-2_amd64.tar.zst

# Verify download
pveam list local
```

### 2. SSH Key

Ensure you have the SSH key configured:

```bash
ls -l /Users/su/Projects/r7700/r77-tf/keys/vm-deb13.pub
```

### 3. Proxmox API Credentials

You'll need API token credentials for Terraform. Set environment variables:

```bash
export TF_VAR_proxmox_api_url="https://192.168.100.1:8006"
export TF_VAR_proxmox_api_token_id="user@pam!terraform=your-secret-token"
export TF_VAR_proxmox_tls_insecure=true
```

Or create a `terraform.tfvars` file in the component directory.

## Deployment Steps

### Step 1: Deploy LXC Container with Terraform

```bash
cd /Users/su/Projects/r7700/r77-tf/components/grafana-stack

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the container
terraform apply

# Note the outputs
terraform output
```

Expected output:
```
container_id = "140"
container_ip = "192.168.100.40"
grafana_url = "http://192.168.100.40:3000"
prometheus_url = "http://192.168.100.40:9090"
alertmanager_url = "http://192.168.100.40:9093"
ssh_connection = "ssh root@192.168.100.40"
```

### Step 2: Verify Container is Running

```bash
# Test SSH access
ssh root@192.168.100.40

# Should connect successfully
# Exit after verification
exit
```

### Step 3: Install Monitoring Stack with Ansible

```bash
cd /Users/su/Projects/r7700/r77-ansible

# Test connectivity
ansible grafana_stack -m ping

# Deploy the monitoring stack
ansible-playbook grafana-stack-setup.yml
```

This will install and configure:
- Grafana v12.3.0
- Prometheus v3.7.3 (15-day retention)
- Loki v3.6.0 (7-day retention)
- AlertManager v0.29.0
- Proxmox PVE Exporter (latest)

Installation takes approximately 5-10 minutes.

### Step 4: Configure Proxmox Monitoring

After installation, configure Proxmox monitoring to visualize your host metrics.

**Quick Setup** (5 minutes):
See [PROXMOX_QUICK_SETUP.md](PROXMOX_QUICK_SETUP.md) for a concise guide.

**Complete Setup** (with alerts and advanced config):
See [PROXMOX_MONITORING_SETUP.md](PROXMOX_MONITORING_SETUP.md) for the full guide.

#### Quick Summary

```bash
# 1. On Proxmox host (192.168.100.4)
pveum user add monitoring@pve
pveum acl modify / --user monitoring@pve --role PVEAuditor
pveum user token add monitoring@pve exporter --privsep 0

# 2. On grafana-stack (192.168.100.40)
nano /etc/prometheus-pve-exporter/pve.yml
```

Update the configuration:

```yaml
default:
  user: monitoring@pve
  token_name: "exporter"
  token_value: "paste-your-token-here"
  verify_ssl: false
```

Save and start the service:

```bash
systemctl restart prometheus-pve-exporter
systemctl status prometheus-pve-exporter

# Verify metrics endpoint
curl http://localhost:9221/metrics
```

### Step 5: Access Grafana

1. **Open Grafana**: http://192.168.100.40:3000

2. **Login with default credentials**:
   - Username: `admin`
   - Password: `admin`

3. **Change password** when prompted

4. **Verify data sources**:
   - Go to Configuration → Data Sources
   - Should see "Prometheus" (default) and "Loki" already configured

### Step 6: Import Dashboards

#### Proxmox Monitoring Dashboard

1. Click **+** → **Import**
2. Enter dashboard ID: **10347** (Proxmox via Prometheus)
3. Click **Load**
4. Select "Prometheus" as data source
5. Click **Import**

#### JMeter Dashboard

1. Click **+** → **Import**
2. Enter dashboard ID: **13865** (JMeter Dashboard using Prometheus)
3. Click **Load**
4. Select "Prometheus" as data source
5. Click **Import**

#### Additional Recommended Dashboards

- **Node Exporter Full**: ID 1860 (if you install node_exporter on hosts)
- **Loki Logs**: ID 13639
- **AlertManager**: ID 9578

## JMeter Integration

Prometheus is pre-configured to scrape JMeter metrics from `192.168.100.23:9270`.

### Test the Integration

1. **Start JMeter test with Prometheus plugin**:
   ```bash
   ssh a1@192.168.100.23
   jmeter -n -t /opt/jmeter-tests/jmeter-prometheus-test.jmx -l results.jtl -Jusers=10 -Jduration=300
   ```

2. **Verify Prometheus is scraping**:
   - Open http://192.168.100.40:9090
   - Go to Status → Targets
   - Look for `jmeter` job - should be "UP" (green)

3. **View metrics in Grafana**:
   - Open the JMeter dashboard
   - You should see live metrics updating

## Configuration Files

### Prometheus Configuration

Location: `/etc/prometheus/prometheus.yml`

Key sections:
- **Scrape interval**: 15s (5s for JMeter during active tests)
- **Retention**: 15 days
- **Storage**: `/var/lib/prometheus`

### Loki Configuration

Location: `/etc/loki/loki.yml`

Key settings:
- **Retention**: 7 days
- **Storage**: `/var/lib/loki`
- **Schema**: v13 (TSDB)

### AlertManager Configuration

Location: `/etc/alertmanager/alertmanager.yml`

To add notification channels, edit this file and add receivers:

```yaml
receivers:
  - name: 'email'
    email_configs:
      - to: 'alerts@example.com'
        from: 'grafana@example.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'user@gmail.com'
        auth_password: 'app-password'
```

Then restart AlertManager:
```bash
systemctl restart alertmanager
```

## Service Management

### Check Service Status

```bash
ssh root@192.168.100.40

# Check all services
systemctl status grafana-server
systemctl status prometheus
systemctl status loki
systemctl status alertmanager
systemctl status prometheus-pve-exporter

# View logs
journalctl -u prometheus -f
journalctl -u grafana-server -f
```

### Restart Services

```bash
systemctl restart prometheus
systemctl restart grafana-server
systemctl restart loki
systemctl restart alertmanager
```

### Reload Prometheus Configuration

Prometheus supports configuration reload without restart:

```bash
# Edit prometheus.yml
nano /etc/prometheus/prometheus.yml

# Reload (without restart)
curl -X POST http://localhost:9090/-/reload

# Or restart if reload doesn't work
systemctl restart prometheus
```

## Storage Management

### Check Disk Usage

```bash
ssh root@192.168.100.40

# Overall disk usage
df -h

# Prometheus data
du -sh /var/lib/prometheus

# Loki data
du -sh /var/lib/loki
```

### Adjust Retention Periods

#### Prometheus Retention

Edit `/etc/systemd/system/prometheus.service`:

```ini
--storage.tsdb.retention.time=15d    # Change to 30d for longer retention
```

Then:
```bash
systemctl daemon-reload
systemctl restart prometheus
```

#### Loki Retention

Edit `/etc/loki/loki.yml`:

```yaml
limits_config:
  retention_period: 7d    # Change to 14d for longer retention
```

Then:
```bash
systemctl restart loki
```

## Adding More Scrape Targets

### Add Node Exporter Hosts

1. Install node_exporter on target hosts
2. Edit `/etc/prometheus/file_sd/node_exporter.yml`:

```yaml
- targets:
    - '192.168.100.11:9100'
  labels:
    instance: 'k8s-cp-1'
    role: 'control-plane'

- targets:
    - '192.168.100.14:9100'
  labels:
    instance: 'k8s-worker-1'
    role: 'worker'
```

3. Prometheus auto-reloads this file every 5 minutes (no restart needed)

### Add Custom Targets

Edit `/etc/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'my-app'
    static_configs:
      - targets: ['192.168.100.50:8080']
        labels:
          service: 'my-application'
```

Reload Prometheus:
```bash
curl -X POST http://localhost:9090/-/reload
```

## Troubleshooting

### Service Won't Start

```bash
# Check service status
systemctl status <service-name>

# View full logs
journalctl -xe -u <service-name>

# Check configuration syntax
# For Prometheus:
/usr/local/bin/promtool check config /etc/prometheus/prometheus.yml

# For Loki:
/usr/local/bin/loki -config.file=/etc/loki/loki.yml -verify-config
```

### PVE Exporter Shows "Down" in Prometheus

1. Check service is running:
   ```bash
   systemctl status prometheus-pve-exporter
   ```

2. Test metrics endpoint:
   ```bash
   curl http://localhost:9221/metrics
   ```

3. Verify Proxmox credentials in `/etc/prometheus-pve-exporter/pve.yml`

4. Check network connectivity to Proxmox:
   ```bash
   curl -k https://192.168.100.1:8006/api2/json
   ```

### JMeter Metrics Not Appearing

1. Verify JMeter test is running with Prometheus plugin
2. Check Prometheus can reach JMeter:
   ```bash
   curl http://192.168.100.23:9270/metrics
   ```
3. Check Prometheus targets: http://192.168.100.40:9090/targets
4. Look for "jmeter" job - if it's red, check firewall/connectivity

### Grafana Data Source Not Working

1. Test connectivity from Grafana container:
   ```bash
   ssh root@192.168.100.40
   curl http://localhost:9090/api/v1/query?query=up
   curl http://localhost:3100/ready
   ```

2. In Grafana UI, go to Data Sources → Prometheus → "Test" button

### Out of Disk Space

1. Check retention periods (see "Adjust Retention Periods" above)
2. Clean old data manually:
   ```bash
   # Prometheus (careful!)
   systemctl stop prometheus
   rm -rf /var/lib/prometheus/data/*
   systemctl start prometheus

   # Loki
   systemctl stop loki
   rm -rf /var/lib/loki/chunks/*
   systemctl start loki
   ```

## Backup & Recovery

### Backup Configuration

```bash
ssh root@192.168.100.40

# Backup configs
tar czf /tmp/monitoring-configs.tar.gz \
  /etc/prometheus \
  /etc/loki \
  /etc/alertmanager \
  /etc/prometheus-pve-exporter \
  /etc/grafana

# Copy to local machine
scp root@192.168.100.40:/tmp/monitoring-configs.tar.gz ~/backups/
```

### Backup Grafana Dashboards

Export dashboards via UI or use Grafana API:

```bash
# List all dashboards
curl -u admin:admin http://192.168.100.40:3000/api/search

# Export dashboard by UID
curl -u admin:admin http://192.168.100.40:3000/api/dashboards/uid/<dashboard-uid> > dashboard.json
```

### LXC Container Snapshot (Recommended)

```bash
# On Proxmox host
ssh root@192.168.100.1

# Create snapshot
pct snapshot 140 backup-$(date +%Y%m%d)

# List snapshots
pct listsnapshot 140

# Rollback if needed
pct rollback 140 backup-20250122
```

## Performance Tuning

### For High-Load Environments (>20 nodes)

1. **Increase container resources**:
   ```bash
   # On Proxmox host
   pct set 140 -cores 6 -memory 12288
   ```

2. **Adjust Prometheus memory**:

   Edit `/etc/systemd/system/prometheus.service`, add:
   ```
   --storage.tsdb.max-block-duration=4h
   ```

3. **Enable Loki query acceleration**:

   In `/etc/loki/loki.yml`:
   ```yaml
   query_scheduler:
     max_outstanding_requests_per_tenant: 2048
   ```

## Uninstall / Destroy

### Remove Container

```bash
cd /Users/su/Projects/r7700/r77-tf/components/grafana-stack
terraform destroy
```

### Remove from Ansible Inventory

Edit `/Users/su/Projects/r7700/r77-ansible/inventory.yml` and remove the `grafana_stack` section.

## Next Steps

1. **Configure alerting rules** in `/etc/prometheus/rules/`
2. **Set up notification channels** in AlertManager
3. **Create custom dashboards** for your specific needs
4. **Install Promtail** on other hosts to send logs to Loki
5. **Configure log shipping** from JMeter to Loki

## Support & Resources

- Grafana Documentation: https://grafana.com/docs/grafana/latest/
- Prometheus Documentation: https://prometheus.io/docs/
- Loki Documentation: https://grafana.com/docs/loki/latest/
- AlertManager Documentation: https://prometheus.io/docs/alerting/alertmanager/
- PVE Exporter: https://github.com/prometheus-pve/prometheus-pve-exporter

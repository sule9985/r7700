# Grafana Stack Bash Setup Guide

A comprehensive guide to understanding and manually setting up the Grafana monitoring stack using bash scripts.

## Table of Contents

1. [Overview](#overview)
2. [Understanding the Components](#understanding-the-components)
3. [Installation Process Explained](#installation-process-explained)
4. [Step-by-Step Breakdown](#step-by-step-breakdown)
5. [Service Management](#service-management)
6. [Configuration Files](#configuration-files)
7. [Troubleshooting](#troubleshooting)

---

## Overview

The Grafana monitoring stack consists of 5 main components working together:

```
┌─────────────────────────────────────────────────────────────┐
│                     MONITORING STACK                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐  ┌────────────┐  ┌──────┐  ┌──────────────┐ │
│  │ Grafana  │◄─┤ Prometheus │◄─┤ Loki │  │ AlertManager │ │
│  │ :3000    │  │ :9090      │  │:3100 │  │ :9093        │ │
│  └──────────┘  └────────────┘  └──────┘  └──────────────┘ │
│       ▲              ▲                                      │
│       │              │                                      │
│       │              │ scrapes metrics                      │
│       │              ▼                                      │
│       │        ┌─────────────┐   ┌────────┐               │
│       │        │ PVE Exporter│   │ JMeter │               │
│       │        │ :9221       │   │ :9270  │               │
│       │        └─────────────┘   └────────┘               │
│       │                                                     │
│       └─ visualizes all data                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Data Flow:**
1. **Exporters** (PVE, JMeter) expose metrics
2. **Prometheus** scrapes and stores metrics
3. **Loki** collects and stores logs
4. **AlertManager** handles alerts from Prometheus
5. **Grafana** visualizes everything in dashboards

---

## Understanding the Components

### 1. Grafana (Visualization)

**Purpose:** Web-based dashboarding and visualization

**What it does:**
- Provides beautiful, interactive dashboards
- Connects to data sources (Prometheus, Loki)
- Allows creating custom queries and alerts
- User-friendly interface for monitoring

**Key concepts:**
- **Datasource:** Where data comes from (Prometheus, Loki)
- **Dashboard:** Collection of panels showing metrics
- **Panel:** Individual graph or table
- **Query:** Request for specific data

**Default credentials:** admin/admin

### 2. Prometheus (Metrics Storage)

**Purpose:** Time-series database and monitoring system

**What it does:**
- **Scrapes metrics** from targets (pull-based)
- **Stores time-series data** efficiently
- **Evaluates rules** and generates alerts
- **Provides query language** (PromQL)

**Key concepts:**
- **Metric:** Measurement over time (e.g., CPU usage)
- **Label:** Key-value pair for categorization
- **Target:** Endpoint to scrape metrics from
- **Scrape:** Process of collecting metrics
- **Retention:** How long to keep data (15 days in our setup)

**Example metric:**
```
cpu_usage{host="server1",core="0"} 45.2
```

### 3. Loki (Log Aggregation)

**Purpose:** Log aggregation and querying

**What it does:**
- **Collects logs** from applications
- **Indexes by labels** (not full-text - efficient!)
- **Stores log content** in chunks
- **Provides query language** (LogQL)

**Key concepts:**
- **Stream:** Sequence of logs from one source
- **Label:** Categorize logs (like Prometheus)
- **Chunk:** Compressed batch of logs
- **Retention:** How long to keep logs (7 days in our setup)

**Difference from Prometheus:**
- Prometheus stores **numbers** (metrics)
- Loki stores **text** (logs)

### 4. AlertManager (Alert Routing)

**Purpose:** Alert handling and notification

**What it does:**
- **Receives alerts** from Prometheus
- **Groups similar alerts** together
- **Routes to receivers** (email, Slack, webhooks)
- **Silences alerts** during maintenance
- **Deduplicates** repeated alerts

**Key concepts:**
- **Route:** How to handle alerts
- **Receiver:** Where to send alerts (email, Slack, etc.)
- **Inhibition:** Suppress alerts based on other alerts
- **Grouping:** Combine similar alerts

### 5. Proxmox PVE Exporter (Metrics Source)

**Purpose:** Export Proxmox metrics for Prometheus

**What it does:**
- **Connects to Proxmox API**
- **Exposes VM/CT metrics** on port 9221
- **Provides node statistics** (CPU, RAM, storage)
- **Updates in real-time**

**Metrics exposed:**
- VM/CT status (running, stopped)
- CPU usage
- Memory usage
- Disk I/O
- Network traffic

---

## Installation Process Explained

### Phase 1: System Preparation

**Why:** Ensure system has required dependencies

```bash
apt-get install -y \
    apt-transport-https \    # For HTTPS repositories
    software-properties-common \  # For adding repos
    wget curl \              # Download tools
    gnupg2 \                 # GPG key verification
    ca-certificates \        # SSL certificates
    adduser \                # Create system users
    libfontconfig1 \         # Grafana dependency
    unzip \                  # Extract archives
    python3 python3-pip      # For PVE exporter
```

### Phase 2: Install Each Component

Each component follows this pattern:

1. **Create dedicated system user** (security)
2. **Download binary** from official source
3. **Create directory structure**
4. **Configure settings**
5. **Create systemd service**
6. **Start and enable service**

---

## Step-by-Step Breakdown

### Step 1: Install Grafana

#### 1.1. Add Repository

```bash
# Why: Grafana provides official APT repository for easy updates
wget -q -O - https://apt.grafana.com/gpg.key | apt-key add -
echo "deb https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
apt-get update
```

#### 1.2. Install Specific Version

```bash
# Why: Pin to specific version for consistency
apt-get install -y grafana=12.3.0
```

#### 1.3. Enable and Start Service

```bash
# Enable: Start on boot
# Start: Start now
systemctl enable grafana-server
systemctl start grafana-server
```

**Result:** Grafana running on http://192.168.100.40:3000

---

### Step 2: Install Prometheus

#### 2.1. Create System User

```bash
# Why: Security - run as unprivileged user
groupadd --system prometheus
useradd --system --no-create-home --shell /usr/sbin/nologin -g prometheus prometheus
```

**Explanation:**
- `--system`: Mark as system user (UID < 1000)
- `--no-create-home`: No home directory needed
- `--shell /usr/sbin/nologin`: Cannot login interactively
- `-g prometheus`: Primary group

#### 2.2. Create Directory Structure

```bash
mkdir -p /etc/prometheus/{rules,file_sd}
mkdir -p /var/lib/prometheus
```

**Directory purposes:**
- `/etc/prometheus/`: Configuration files
- `/etc/prometheus/rules/`: Alert rules (YAML)
- `/etc/prometheus/file_sd/`: Service discovery files
- `/var/lib/prometheus/`: Time-series database

#### 2.3. Download and Extract

```bash
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v3.7.3/prometheus-3.7.3.linux-amd64.tar.gz
tar -xzf prometheus-3.7.3.linux-amd64.tar.gz
```

#### 2.4. Install Binaries

```bash
cp prometheus-3.7.3.linux-amd64/prometheus /usr/local/bin/
cp prometheus-3.7.3.linux-amd64/promtool /usr/local/bin/
```

**Binaries:**
- `prometheus`: Main server
- `promtool`: Validation and testing tool

#### 2.5. Copy Console Files

```bash
cp -r prometheus-3.7.3.linux-amd64/consoles /etc/prometheus/
cp -r prometheus-3.7.3.linux-amd64/console_libraries /etc/prometheus/
```

**Purpose:** Web console templates for built-in UI

#### 2.6. Set Permissions

```bash
chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus
```

**Why:** Prometheus user must own its files

#### 2.7. Create Configuration File

```yaml
# /etc/prometheus/prometheus.yml

global:
  scrape_interval: 15s       # How often to scrape targets
  evaluation_interval: 15s   # How often to evaluate rules

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

**Key settings:**
- `scrape_interval`: Balance between freshness and load
- `scrape_configs`: List of targets to monitor
- `job_name`: Logical grouping of targets

#### 2.8. Create Systemd Service

```ini
# /etc/systemd/system/prometheus.service

[Unit]
Description=Prometheus Monitoring System
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=15d \
  --web.listen-address=0.0.0.0:9090
Restart=always

[Install]
WantedBy=multi-user.target
```

**Explanation:**
- `Type=simple`: Foreground process
- `User=prometheus`: Run as prometheus user
- `ExecStart`: Command to run
- `--config.file`: Path to config
- `--storage.tsdb.path`: Where to store data
- `--storage.tsdb.retention.time=15d`: Keep data for 15 days
- `--web.listen-address`: Listen on all interfaces
- `Restart=always`: Auto-restart on failure

#### 2.9. Start Service

```bash
systemctl daemon-reload      # Reload systemd config
systemctl enable prometheus  # Start on boot
systemctl start prometheus   # Start now
```

**Result:** Prometheus running on http://192.168.100.40:9090

---

### Step 3: Install Loki

*Similar process to Prometheus:*

#### 3.1. Create User and Directories

```bash
groupadd --system loki
useradd --system --no-create-home --shell /usr/sbin/nologin -g loki loki
mkdir -p /etc/loki
mkdir -p /var/lib/loki/{chunks,index,rules}
```

**Directories:**
- `chunks/`: Compressed log data
- `index/`: Index for fast searching
- `rules/`: LogQL alert rules

#### 3.2. Download Binary

```bash
wget https://github.com/grafana/loki/releases/download/v3.6.0/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
cp loki-linux-amd64 /usr/local/bin/loki
chmod +x /usr/local/bin/loki
```

**Note:** Loki is distributed as single binary in ZIP file

#### 3.3. Create Configuration

```yaml
# /etc/loki/loki.yml

auth_enabled: false  # No authentication for single-instance

server:
  http_listen_port: 3100

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb          # Time-series index
      object_store: filesystem
      schema: v13

limits_config:
  retention_period: 7d   # Keep logs for 7 days
```

**Key concepts:**
- `schema`: Index format (v13 is latest)
- `store: tsdb`: Use time-series database index
- `object_store: filesystem`: Store on local disk
- `retention_period`: Auto-delete old logs

#### 3.4. Create Service and Start

```bash
# Create systemd service (similar to Prometheus)
systemctl daemon-reload
systemctl enable loki
systemctl start loki
```

**Result:** Loki running on http://192.168.100.40:3100

---

### Step 4: Install AlertManager

*Similar process, simpler configuration:*

#### 4.1-4.3. User, Download, Install

```bash
# Create user
groupadd --system alertmanager
useradd --system --no-create-home --shell /usr/sbin/nologin -g alertmanager alertmanager

# Download and extract
wget https://github.com/prometheus/alertmanager/releases/download/v0.29.0/alertmanager-0.29.0.linux-amd64.tar.gz
tar -xzf alertmanager-0.29.0.linux-amd64.tar.gz

# Install binaries
cp alertmanager-0.29.0.linux-amd64/alertmanager /usr/local/bin/
cp alertmanager-0.29.0.linux-amd64/amtool /usr/local/bin/
```

#### 4.4. Configure

```yaml
# /etc/alertmanager/alertmanager.yml

global:
  resolve_timeout: 5m  # Mark alert as resolved after 5 min

route:
  group_by: ['alertname']  # Group similar alerts
  receiver: 'default'      # Where to send

receivers:
  - name: 'default'
    # Add notification channels here
    # email_configs, slack_configs, webhook_configs, etc.
```

**Configuration structure:**
- `route`: How to route alerts
- `receivers`: Where to send alerts
- `inhibit_rules`: Suppress alerts based on conditions

#### 4.5. Start Service

```bash
systemctl enable alertmanager
systemctl start alertmanager
```

**Result:** AlertManager running on http://192.168.100.40:9093

---

### Step 5: Install Proxmox PVE Exporter

#### 5.1. Create User

```bash
useradd --system --no-create-home --shell /usr/sbin/nologin pve-exporter
```

#### 5.2. Install via pip

```bash
pip3 install prometheus-pve-exporter --break-system-packages
```

**Why pip:**
- PVE exporter is a Python application
- Easier to maintain and update
- `--break-system-packages`: Allow installation on Debian 12+

#### 5.3. Create Configuration

```yaml
# /etc/prometheus-pve-exporter/pve.yml

default:
  user: monitoring@pve
  password: "CHANGE_ME"  # Or use token authentication
  verify_ssl: false      # Self-signed cert on Proxmox
```

**Authentication options:**
1. **Password:** Simple but less secure
2. **API Token:** More secure, recommended

**Create Proxmox monitoring user:**
```bash
# On Proxmox host
pveum user add monitoring@pve
pveum acl modify / -user monitoring@pve -role PVEAuditor
pveum user token add monitoring@pve exporter -privsep 0
```

#### 5.4. Create Service

```bash
systemctl enable prometheus-pve-exporter
# Don't start until credentials configured!
```

**Result:** PVE exporter ready (start after config)

---

### Step 6: Configure Grafana Datasources

#### 6.1. Add Prometheus Datasource

```bash
curl -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://localhost:9090",
    "access": "proxy",
    "isDefault": true
  }'
```

**Parameters:**
- `name`: Datasource name in Grafana
- `type`: Datasource plugin type
- `url`: Where Grafana connects to
- `access: "proxy"`: Grafana proxies requests (server-side)
- `isDefault: true`: Use by default in new panels

#### 6.2. Add Loki Datasource

```bash
curl -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Loki",
    "type": "loki",
    "url": "http://localhost:3100",
    "access": "proxy"
  }'
```

**Result:** Grafana can now query Prometheus and Loki

---

## Service Management

### Systemd Commands

```bash
# Check status
systemctl status <service>

# Start service
systemctl start <service>

# Stop service
systemctl stop <service>

# Restart service
systemctl restart <service>

# Enable on boot
systemctl enable <service>

# Disable on boot
systemctl disable <service>

# View logs (follow mode)
journalctl -u <service> -f

# View recent logs
journalctl -u <service> -n 50
```

### Services Names

- `grafana-server`
- `prometheus`
- `loki`
- `alertmanager`
- `prometheus-pve-exporter`

### Health Checks

```bash
# Grafana
curl http://localhost:3000/api/health

# Prometheus
curl http://localhost:9090/-/healthy

# Loki
curl http://localhost:3100/ready

# AlertManager
curl http://localhost:9093/-/healthy

# PVE Exporter
curl http://localhost:9221/metrics
```

---

## Configuration Files

### Prometheus Configuration

**Location:** `/etc/prometheus/prometheus.yml`

**Reload without restart:**
```bash
# Send SIGHUP signal
kill -HUP $(cat /var/run/prometheus.pid)

# Or use HTTP API (if --web.enable-lifecycle)
curl -X POST http://localhost:9090/-/reload
```

**Validate configuration:**
```bash
/usr/local/bin/promtool check config /etc/prometheus/prometheus.yml
```

### Loki Configuration

**Location:** `/etc/loki/loki.yml`

**Validate configuration:**
```bash
/usr/local/bin/loki -config.file=/etc/loki/loki.yml -verify-config
```

**Restart required for changes:**
```bash
systemctl restart loki
```

### AlertManager Configuration

**Location:** `/etc/alertmanager/alertmanager.yml`

**Validate:**
```bash
/usr/local/bin/amtool check-config /etc/alertmanager/alertmanager.yml
```

**Reload:**
```bash
curl -X POST http://localhost:9093/-/reload
```

---

## Troubleshooting

### Service Won't Start

```bash
# Check detailed status
systemctl status <service>

# Check logs
journalctl -xe -u <service>

# Check config
# For Prometheus:
/usr/local/bin/promtool check config /etc/prometheus/prometheus.yml

# For Loki:
/usr/local/bin/loki -config.file=/etc/loki/loki.yml -verify-config
```

### Port Already in Use

```bash
# Find what's using port
ss -tlnp | grep :<port>

# Kill process
kill <pid>

# Or change port in config
```

### Permission Denied

```bash
# Check file ownership
ls -la /etc/prometheus/
ls -la /var/lib/prometheus/

# Fix ownership
chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus
```

### Out of Disk Space

```bash
# Check disk usage
df -h
du -sh /var/lib/prometheus
du -sh /var/lib/loki

# Reduce retention
# Edit config files and restart services
```

### Cannot Access Web UI

```bash
# Check service is running
systemctl status <service>

# Check port is listening
ss -tlnp | grep :<port>

# Check firewall
ufw status

# Test from container
curl http://localhost:<port>

# Test from outside
curl http://192.168.100.40:<port>
```

---

## Using the Setup Script

### 1. Copy Script to Container

```bash
# From your local machine
scp r77-ansible/grafana-stack-manual-setup.sh root@192.168.100.40:/root/
```

### 2. Make Executable

```bash
# SSH to container
ssh root@192.168.100.40

# Make executable
chmod +x /root/grafana-stack-manual-setup.sh
```

### 3. Run Script

```bash
# Run with root privileges
./grafana-stack-manual-setup.sh
```

**The script will:**
1. Show what will be installed
2. Ask for confirmation
3. Install all components step-by-step
4. Configure datasources
5. Verify installation
6. Display summary with URLs and next steps

### 4. Post-Installation

```bash
# Configure Proxmox credentials
nano /etc/prometheus-pve-exporter/pve.yml

# Start PVE exporter
systemctl start prometheus-pve-exporter

# Access Grafana
# Browser: http://192.168.100.40:3000
# Login: admin/admin
```

---

## Understanding Key Concepts

### Metrics vs Logs

| Aspect | Metrics (Prometheus) | Logs (Loki) |
|--------|---------------------|-------------|
| **Data Type** | Numbers | Text |
| **Example** | `cpu_usage=45.2` | `ERROR: Connection failed` |
| **Storage** | Time-series database | Compressed chunks |
| **Query** | PromQL | LogQL |
| **Use Case** | Trending, alerts | Debugging, audit |
| **Size** | Small (efficient) | Large (verbose) |

### Pull vs Push

**Prometheus (Pull):**
- Prometheus scrapes targets
- Targets expose metrics on HTTP endpoint
- Prometheus controls scrape frequency
- Better for service discovery

**Push (Alternative):**
- Application sends data to collector
- Used by: Loki (via promtail), some metrics systems
- Good for short-lived jobs

### Labels and Dimensions

```
# Metric with labels
http_requests_total{method="GET",status="200",handler="/api/users"} 1234

# Labels allow filtering:
http_requests_total{status="500"}           # Only errors
http_requests_total{handler="/api/users"}   # Only user API
```

**Benefits:**
- Multi-dimensional data
- Flexible querying
- Efficient storage

### Retention and Compaction

**Prometheus:**
- Stores data in 2-hour blocks
- Compacts old blocks
- Deletes data older than retention (15d)

**Loki:**
- Compacts chunks periodically
- Applies retention policy
- Deletes old data automatically

---

## Summary

**Installation Order:**
1. System preparation
2. Grafana (visualization)
3. Prometheus (metrics)
4. Loki (logs)
5. AlertManager (alerts)
6. PVE Exporter (Proxmox metrics)
7. Configure datasources

**Key Files:**
- Binaries: `/usr/local/bin/`
- Configs: `/etc/<service>/`
- Data: `/var/lib/<service>/`
- Services: `/etc/systemd/system/<service>.service`

**Ports:**
- 3000: Grafana
- 9090: Prometheus
- 3100: Loki
- 9093: AlertManager
- 9221: PVE Exporter
- 9270: JMeter (external)

**Next Steps After Installation:**
1. Configure Proxmox credentials
2. Change Grafana password
3. Import dashboards
4. Configure alerts
5. Add more targets

---

**Created:** 2025-01-22
**For:** Understanding Grafana Stack Manual Installation
**Script:** r77-ansible/grafana-stack-manual-setup.sh

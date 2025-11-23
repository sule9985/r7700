#!/bin/bash
# Grafana Stack Manual Setup Script
# This script installs and configures a complete monitoring stack on Debian 12/13 LXC
# Components: Grafana, Prometheus, Loki, AlertManager, Proxmox PVE Exporter
#
# Usage:
#   1. Copy this script to your LXC container
#   2. Make it executable: chmod +x grafana-stack-manual-setup.sh
#   3. Run as root: ./grafana-stack-manual-setup.sh
#
# Target: LXC Container at 192.168.100.40 (grafana-stack)

set -e  # Exit on any error
set -u  # Exit on undefined variable

#==============================================================================
# CONFIGURATION VARIABLES
#==============================================================================

# Service versions
GRAFANA_VERSION="12.3.0"
PROMETHEUS_VERSION="3.7.3"
LOKI_VERSION="3.6.0"
ALERTMANAGER_VERSION="0.29.0"

# Prometheus configuration
PROMETHEUS_RETENTION="15d"
PROMETHEUS_STORAGE="/var/lib/prometheus"

# Loki configuration
LOKI_RETENTION_DAYS="7"
LOKI_STORAGE="/var/lib/loki"

# Integration settings
PROXMOX_HOST="192.168.100.4"
PROXMOX_PORT="8006"
JMETER_HOST="192.168.100.23"
JMETER_PORT="9270"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

#==============================================================================
# SYSTEM PREPARATION
#==============================================================================

setup_system() {
    print_header "SYSTEM PREPARATION"

    print_step "Updating package cache..."
    apt-get update -qq

    print_step "Installing base packages..."
    apt-get install -y \
        apt-transport-https \
        wget \
        curl \
        gnupg2 \
        ca-certificates \
        adduser \
        libfontconfig1 \
        unzip \
        python3 \
        python3-pip

    print_success "System preparation complete"
}

#==============================================================================
# GRAFANA INSTALLATION
#==============================================================================

install_grafana() {
    print_header "INSTALLING GRAFANA v${GRAFANA_VERSION}"

    print_step "Adding Grafana GPG key..."
    # Modern method for Debian 12/13 (apt-key is deprecated)
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana-archive-keyring.gpg

    print_step "Adding Grafana repository..."
    echo "deb [signed-by=/usr/share/keyrings/grafana-archive-keyring.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list

    print_step "Updating package cache..."
    apt-get update -qq

    print_step "Installing Grafana ${GRAFANA_VERSION}..."
    apt-get install -y grafana=${GRAFANA_VERSION}

    print_step "Enabling and starting Grafana service..."
    systemctl daemon-reload
    systemctl enable grafana-server
    systemctl start grafana-server

    # Wait for Grafana to start
    print_step "Waiting for Grafana to be ready..."
    sleep 5

    # Check if Grafana is running
    if systemctl is-active --quiet grafana-server; then
        print_success "Grafana installed and running on port 3000"
        print_info "Access: http://192.168.100.40:3000 (admin/admin)"
    else
        print_error "Grafana failed to start"
        journalctl -u grafana-server -n 20 --no-pager
        exit 1
    fi
}

#==============================================================================
# PROMETHEUS INSTALLATION
#==============================================================================

install_prometheus() {
    print_header "INSTALLING PROMETHEUS v${PROMETHEUS_VERSION}"

    # Create prometheus user and group
    print_step "Creating prometheus system user..."
    if ! id -u prometheus >/dev/null 2>&1; then
        groupadd --system prometheus
        useradd --system --no-create-home --shell /usr/sbin/nologin -g prometheus prometheus
        print_info "Created prometheus user"
    else
        print_info "Prometheus user already exists"
    fi

    # Create directories
    print_step "Creating Prometheus directories..."
    mkdir -p /etc/prometheus/{rules,file_sd}
    mkdir -p ${PROMETHEUS_STORAGE}
    mkdir -p /var/lib/prometheus

    # Download Prometheus
    print_step "Downloading Prometheus ${PROMETHEUS_VERSION}..."
    cd /tmp
    wget -q --show-progress \
        https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

    print_step "Extracting Prometheus..."
    tar -xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

    # Stop Prometheus if already running (for re-runs)
    if systemctl is-active --quiet prometheus 2>/dev/null; then
        print_step "Stopping existing Prometheus service..."
        systemctl stop prometheus
    fi

    # Install binaries
    print_step "Installing Prometheus binaries..."
    cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/
    cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/

    # Copy console files (if they exist - not included in Prometheus 3.x)
    print_step "Copying console templates (if available)..."
    if [ -d "prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles" ]; then
        cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles /etc/prometheus/
        cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries /etc/prometheus/
        print_info "Console templates copied"
    else
        print_info "Console templates not included in this version (Prometheus 3.x+)"
        # Create empty directories to prevent errors
        mkdir -p /etc/prometheus/consoles
        mkdir -p /etc/prometheus/console_libraries
    fi

    # Set ownership
    print_step "Setting file permissions..."
    chown -R prometheus:prometheus /etc/prometheus
    chown -R prometheus:prometheus ${PROMETHEUS_STORAGE}
    chown prometheus:prometheus /usr/local/bin/prometheus
    chown prometheus:prometheus /usr/local/bin/promtool

    # Create configuration file
    print_step "Creating Prometheus configuration..."
    cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'grafana-stack'
    cluster: 'proxmox-homelab'

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - localhost:9093

# Rule files
rule_files:
  - /etc/prometheus/rules/*.yml

# Scrape configurations
scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          service: 'prometheus'

  # Proxmox PVE Exporter
  - job_name: 'proxmox'
    static_configs:
      - targets: ['localhost:9221']
        labels:
          service: 'proxmox-pve'
          instance: 'pve-host'

  # JMeter Load Testing Metrics
  - job_name: 'jmeter'
    static_configs:
      - targets: ['JMETER_HOST:JMETER_PORT']
        labels:
          service: 'jmeter'
          instance: 'load-generator'
    scrape_interval: 5s  # More frequent for active tests

  # Node Exporter (if installed on other hosts)
  - job_name: 'node'
    file_sd_configs:
      - files:
          - /etc/prometheus/file_sd/node_exporter.yml
        refresh_interval: 5m
EOF

    # Replace placeholders
    sed -i "s/JMETER_HOST/${JMETER_HOST}/g" /etc/prometheus/prometheus.yml
    sed -i "s/JMETER_PORT/${JMETER_PORT}/g" /etc/prometheus/prometheus.yml

    chown prometheus:prometheus /etc/prometheus/prometheus.yml

    # Create empty node exporter file
    cat > /etc/prometheus/file_sd/node_exporter.yml << 'EOF'
# Add node_exporter targets here
# Example:
# - targets:
#     - '192.168.100.11:9100'
#   labels:
#     instance: 'k8s-cp-1'
#     role: 'control-plane'
EOF
    chown prometheus:prometheus /etc/prometheus/file_sd/node_exporter.yml

    # Create systemd service
    print_step "Creating Prometheus systemd service..."
    cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus Monitoring System
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=${PROMETHEUS_STORAGE} \\
  --storage.tsdb.retention.time=${PROMETHEUS_RETENTION} \\
  --web.listen-address=0.0.0.0:9090 \\
  --web.enable-lifecycle
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    print_step "Starting Prometheus..."
    systemctl daemon-reload
    systemctl enable prometheus
    systemctl start prometheus

    # Wait and check
    sleep 3
    if systemctl is-active --quiet prometheus; then
        print_success "Prometheus installed and running on port 9090"
        print_info "Access: http://192.168.100.40:9090"
    else
        print_error "Prometheus failed to start"
        journalctl -u prometheus -n 20 --no-pager
        exit 1
    fi

    # Cleanup
    print_step "Cleaning up..."
    rm -rf /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64*
}

#==============================================================================
# LOKI INSTALLATION
#==============================================================================

install_loki() {
    print_header "INSTALLING LOKI v${LOKI_VERSION}"

    # Create loki user
    print_step "Creating loki system user..."
    if ! id -u loki >/dev/null 2>&1; then
        groupadd --system loki
        useradd --system --no-create-home --shell /usr/sbin/nologin -g loki loki
        print_info "Created loki user"
    else
        print_info "Loki user already exists"
    fi

    # Create directories
    print_step "Creating Loki directories..."
    mkdir -p /etc/loki
    mkdir -p ${LOKI_STORAGE}/{chunks,index,rules,compactor}

    # Download Loki
    print_step "Downloading Loki ${LOKI_VERSION}..."
    cd /tmp
    wget -q --show-progress \
        https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip

    print_step "Extracting Loki..."
    unzip -o loki-linux-amd64.zip

    # Stop Loki if already running (for re-runs)
    if systemctl is-active --quiet loki 2>/dev/null; then
        print_step "Stopping existing Loki service..."
        systemctl stop loki
    fi

    # Install binary
    print_step "Installing Loki binary..."
    cp loki-linux-amd64 /usr/local/bin/loki
    chmod +x /usr/local/bin/loki
    chown loki:loki /usr/local/bin/loki

    # Set ownership
    chown -R loki:loki /etc/loki
    chown -R loki:loki ${LOKI_STORAGE}

    # Create configuration (Loki 3.x compatible)
    print_step "Creating Loki configuration..."
    cat > /etc/loki/loki.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: info

common:
  instance_addr: 127.0.0.1
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

# Pattern ingester for log parsing
pattern_ingester:
  enabled: false

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  tsdb_shipper:
    active_index_directory: /var/lib/loki/index
    cache_location: /var/lib/loki/index_cache
  filesystem:
    directory: /var/lib/loki/chunks

limits_config:
  retention_period: 7d
  split_queries_by_interval: 24h
  max_cache_freshness_per_query: 10m
  reject_old_samples: true
  reject_old_samples_max_age: 168h

table_manager:
  retention_deletes_enabled: true
  retention_period: 7d

compactor:
  working_directory: /var/lib/loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
  delete_request_store: filesystem
EOF

    chown loki:loki /etc/loki/loki.yml

    # Create systemd service
    print_step "Creating Loki systemd service..."
    cat > /etc/systemd/system/loki.service << 'EOF'
[Unit]
Description=Loki Log Aggregation System
Documentation=https://grafana.com/docs/loki/latest/
After=network-online.target

[Service]
Type=simple
User=loki
Group=loki
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    print_step "Starting Loki..."
    systemctl daemon-reload
    systemctl enable loki
    systemctl start loki

    # Wait and check
    sleep 3
    if systemctl is-active --quiet loki; then
        print_success "Loki installed and running on port 3100"
        print_info "Access: http://192.168.100.40:3100/ready"
    else
        print_error "Loki failed to start"
        journalctl -u loki -n 20 --no-pager
        exit 1
    fi

    # Cleanup
    print_step "Cleaning up..."
    rm -f /tmp/loki-linux-amd64*
}

#==============================================================================
# ALERTMANAGER INSTALLATION
#==============================================================================

install_alertmanager() {
    print_header "INSTALLING ALERTMANAGER v${ALERTMANAGER_VERSION}"

    # Create alertmanager user
    print_step "Creating alertmanager system user..."
    if ! id -u alertmanager >/dev/null 2>&1; then
        groupadd --system alertmanager
        useradd --system --no-create-home --shell /usr/sbin/nologin -g alertmanager alertmanager
        print_info "Created alertmanager user"
    else
        print_info "AlertManager user already exists"
    fi

    # Create directories
    print_step "Creating AlertManager directories..."
    mkdir -p /etc/alertmanager
    mkdir -p /var/lib/alertmanager

    # Download AlertManager
    print_step "Downloading AlertManager ${ALERTMANAGER_VERSION}..."
    cd /tmp
    wget -q --show-progress \
        https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz

    print_step "Extracting AlertManager..."
    tar -xzf alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz

    # Stop AlertManager if already running (for re-runs)
    if systemctl is-active --quiet alertmanager 2>/dev/null; then
        print_step "Stopping existing AlertManager service..."
        systemctl stop alertmanager
    fi

    # Install binaries
    print_step "Installing AlertManager binaries..."
    cp alertmanager-${ALERTMANAGER_VERSION}.linux-amd64/alertmanager /usr/local/bin/
    cp alertmanager-${ALERTMANAGER_VERSION}.linux-amd64/amtool /usr/local/bin/

    # Set ownership
    chown -R alertmanager:alertmanager /etc/alertmanager
    chown -R alertmanager:alertmanager /var/lib/alertmanager
    chown alertmanager:alertmanager /usr/local/bin/alertmanager
    chown alertmanager:alertmanager /usr/local/bin/amtool

    # Create configuration
    print_step "Creating AlertManager configuration..."
    cat > /etc/alertmanager/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'

receivers:
  - name: 'default'
    # Configure your notification channels here
    # Examples: email, slack, pagerduty, webhook
    # webhook_configs:
    #   - url: 'http://example.com/webhook'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster', 'service']
EOF

    chown alertmanager:alertmanager /etc/alertmanager/alertmanager.yml

    # Create systemd service
    print_step "Creating AlertManager systemd service..."
    cat > /etc/systemd/system/alertmanager.service << 'EOF'
[Unit]
Description=Prometheus AlertManager
Documentation=https://prometheus.io/docs/alerting/alertmanager/
After=network-online.target

[Service]
Type=simple
User=alertmanager
Group=alertmanager
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager \
  --web.listen-address=0.0.0.0:9093
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    print_step "Starting AlertManager..."
    systemctl daemon-reload
    systemctl enable alertmanager
    systemctl start alertmanager

    # Wait and check
    sleep 3
    if systemctl is-active --quiet alertmanager; then
        print_success "AlertManager installed and running on port 9093"
        print_info "Access: http://192.168.100.40:9093"
    else
        print_error "AlertManager failed to start"
        journalctl -u alertmanager -n 20 --no-pager
        exit 1
    fi

    # Cleanup
    print_step "Cleaning up..."
    rm -rf /tmp/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64*
}

#==============================================================================
# PROXMOX PVE EXPORTER INSTALLATION
#==============================================================================

install_pve_exporter() {
    print_header "INSTALLING PROXMOX PVE EXPORTER"

    # Create pve-exporter user
    print_step "Creating pve-exporter system user..."
    if ! id -u pve-exporter >/dev/null 2>&1; then
        useradd --system --no-create-home --shell /usr/sbin/nologin pve-exporter
        print_info "Created pve-exporter user"
    else
        print_info "PVE exporter user already exists"
    fi

    # Install via pip
    print_step "Installing prometheus-pve-exporter via pip..."
    pip3 install prometheus-pve-exporter --break-system-packages

    # Create config directory
    print_step "Creating PVE exporter configuration..."
    mkdir -p /etc/prometheus-pve-exporter

    cat > /etc/prometheus-pve-exporter/pve.yml << EOF
default:
  user: monitoring@pve
  # IMPORTANT: Create a read-only user on Proxmox for monitoring
  # On Proxmox host:
  #   pveum user add monitoring@pve
  #   pveum acl modify / -user monitoring@pve -role PVEAuditor
  #   pveum user token add monitoring@pve exporter -privsep 0
  # Then add the token here:
  # token_name: "exporter"
  # token_value: "your-token-here"
  # OR use password:
  password: "CHANGE_ME"
  verify_ssl: false
EOF

    # Create systemd service
    print_step "Creating PVE exporter systemd service..."
    cat > /etc/systemd/system/prometheus-pve-exporter.service << 'EOF'
[Unit]
Description=Prometheus Proxmox VE Exporter
Documentation=https://github.com/prometheus-pve/prometheus-pve-exporter
After=network-online.target

[Service]
Type=simple
User=pve-exporter
Group=pve-exporter
ExecStart=/usr/local/bin/pve_exporter \
  --config.file=/etc/prometheus-pve-exporter/pve.yml \
  --web.listen-address=0.0.0.0:9221
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Enable service (but don't start until configured)
    print_step "Enabling PVE exporter service..."
    systemctl daemon-reload
    systemctl enable prometheus-pve-exporter

    print_info "PVE exporter installed but NOT started"
    print_info "Configure credentials in /etc/prometheus-pve-exporter/pve.yml first"
    print_info "Then start with: systemctl start prometheus-pve-exporter"
}

#==============================================================================
# GRAFANA DATA SOURCE CONFIGURATION
#==============================================================================

configure_grafana_datasources() {
    print_header "CONFIGURING GRAFANA DATA SOURCES"

    print_step "Waiting for Grafana to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:3000/api/health | grep -q "ok"; then
            print_info "Grafana is ready"
            break
        fi
        sleep 2
    done

    print_step "Adding Prometheus datasource..."
    curl -s -X POST http://admin:admin@localhost:3000/api/datasources \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Prometheus",
            "type": "prometheus",
            "url": "http://localhost:9090",
            "access": "proxy",
            "isDefault": true,
            "jsonData": {
                "timeInterval": "15s"
            }
        }' > /dev/null 2>&1 || true

    print_step "Adding Loki datasource..."
    curl -s -X POST http://admin:admin@localhost:3000/api/datasources \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Loki",
            "type": "loki",
            "url": "http://localhost:3100",
            "access": "proxy",
            "jsonData": {
                "maxLines": 1000
            }
        }' > /dev/null 2>&1 || true

    print_success "Grafana datasources configured"
}

#==============================================================================
# VERIFICATION
#==============================================================================

verify_installation() {
    print_header "VERIFYING INSTALLATION"

    echo ""
    print_step "Checking service status..."
    echo ""

    services=("grafana-server" "prometheus" "loki" "alertmanager")
    all_running=true

    for service in "${services[@]}"; do
        if systemctl is-active --quiet $service; then
            echo -e "  ${GREEN}✓${NC} $service: ${GREEN}running${NC}"
        else
            echo -e "  ${RED}✗${NC} $service: ${RED}stopped${NC}"
            all_running=false
        fi
    done

    # PVE exporter status
    if systemctl is-active --quiet prometheus-pve-exporter; then
        echo -e "  ${GREEN}✓${NC} prometheus-pve-exporter: ${GREEN}running${NC}"
    else
        echo -e "  ${YELLOW}!${NC} prometheus-pve-exporter: ${YELLOW}not configured${NC}"
    fi

    echo ""
    print_step "Checking network connectivity..."
    echo ""

    ports=("3000:Grafana" "9090:Prometheus" "3100:Loki" "9093:AlertManager")

    for port_info in "${ports[@]}"; do
        port="${port_info%%:*}"
        name="${port_info##*:}"
        if nc -z localhost $port 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Port $port ($name): ${GREEN}listening${NC}"
        else
            echo -e "  ${RED}✗${NC} Port $port ($name): ${RED}not listening${NC}"
            all_running=false
        fi
    done

    echo ""

    if $all_running; then
        print_success "All services verified successfully!"
    else
        print_error "Some services are not running properly"
        return 1
    fi
}

#==============================================================================
# DISPLAY SUMMARY
#==============================================================================

display_summary() {
    print_header "DEPLOYMENT SUMMARY"

    cat << EOF

${GREEN}Grafana Stack Installation Complete!${NC}

${BLUE}Access URLs:${NC}
  Grafana:      http://192.168.100.40:3000
  Prometheus:   http://192.168.100.40:9090
  AlertManager: http://192.168.100.40:9093
  Loki API:     http://192.168.100.40:3100

${BLUE}Default Credentials:${NC}
  Grafana: admin / admin (change on first login)

${BLUE}Service Versions:${NC}
  Grafana:      v${GRAFANA_VERSION}
  Prometheus:   v${PROMETHEUS_VERSION}
  Loki:         v${LOKI_VERSION}
  AlertManager: v${ALERTMANAGER_VERSION}

${BLUE}Next Steps:${NC}
  1. Configure Proxmox credentials:
     ${YELLOW}nano /etc/prometheus-pve-exporter/pve.yml${NC}

  2. Start PVE exporter:
     ${YELLOW}systemctl start prometheus-pve-exporter${NC}

  3. Access Grafana and change default password:
     ${YELLOW}http://192.168.100.40:3000${NC}

  4. Import dashboards:
     - Proxmox: Dashboard ID 10347
     - JMeter: Dashboard ID 13865

  5. Configure AlertManager notification channels:
     ${YELLOW}nano /etc/alertmanager/alertmanager.yml${NC}
     ${YELLOW}systemctl restart alertmanager${NC}

${BLUE}JMeter Integration:${NC}
  Prometheus is configured to scrape:
  - Target: ${JMETER_HOST}:${JMETER_PORT}
  - Interval: 5 seconds
  - Start JMeter tests with Prometheus plugin to see metrics

${BLUE}Service Management:${NC}
  Check status:  ${YELLOW}systemctl status <service>${NC}
  Restart:       ${YELLOW}systemctl restart <service>${NC}
  View logs:     ${YELLOW}journalctl -u <service> -f${NC}

  Services: grafana-server, prometheus, loki, alertmanager, prometheus-pve-exporter

${BLUE}Configuration Files:${NC}
  Prometheus:   /etc/prometheus/prometheus.yml
  Loki:         /etc/loki/loki.yml
  AlertManager: /etc/alertmanager/alertmanager.yml
  PVE Exporter: /etc/prometheus-pve-exporter/pve.yml

${GREEN}Installation completed at: $(date)${NC}

EOF
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

main() {
    clear
    print_header "GRAFANA MONITORING STACK INSTALLER"

    echo "This script will install:"
    echo "  - Grafana ${GRAFANA_VERSION}"
    echo "  - Prometheus ${PROMETHEUS_VERSION}"
    echo "  - Loki ${LOKI_VERSION}"
    echo "  - AlertManager ${ALERTMANAGER_VERSION}"
    echo "  - Proxmox PVE Exporter"
    echo ""
    echo "Target: LXC Container at 192.168.100.40"
    echo ""

    # Check if running as root
    check_root

    # Confirmation
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi

    # Start installation
    START_TIME=$(date +%s)

    # Execute installation steps
    setup_system
    install_grafana
    install_prometheus
    install_loki
    install_alertmanager
    install_pve_exporter
    configure_grafana_datasources

    # Verify installation
    if verify_installation; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))

        echo ""
        print_success "Installation completed successfully in ${DURATION} seconds!"

        # Display summary
        display_summary

        exit 0
    else
        print_error "Installation completed with errors"
        print_info "Check service logs with: journalctl -u <service-name>"
        exit 1
    fi
}

# Run main function
main

# JMeter Load Testing Component

Terraform component for deploying a dedicated Apache JMeter load testing server on Proxmox.

## Overview

This component provisions a high-performance VM for running JMeter in non-GUI (headless) mode, designed for:
- **Performance testing** of web applications and APIs
- **Load testing** with thousands of concurrent users
- **Stress testing** to find breaking points
- **Integration** with Grafana for real-time metrics

## VM Specifications

| Component | Value |
|-----------|-------|
| Hostname | jmeter |
| IP Address | 192.168.100.23 |
| VMID | 123 |
| CPU | 16 cores |
| Memory | 32GB |
| Disk | 80GB |
| OS | Debian 13 (cloud-init) |
| **Max Capacity** | **5000 concurrent users** |

### Why These Specs?

- **16 CPU cores**: JMeter is multi-threaded; handles ~300-400 users per core = 5000+ users total
- **32GB RAM**: Supports 24GB JVM heap for 5000 concurrent users (each user ~3-5MB RAM)
- **80GB disk**: Large storage for JMeter binaries, test plans, massive result files, and HTML reports
- **System tuning**: Kernel parameters optimized for high concurrency (1M file descriptors, 64K ports)

## Prerequisites

1. **Proxmox VE** with API access
2. **Debian 13 template** (VMID 998 or 999) with:
   - cloud-init support
   - qemu-guest-agent installed
3. **SSH public key** at `~/.ssh/vm-deb13.pub`
4. **Network access** to systems under test

## Quick Start

### 1. Configure Credentials

```bash
cd r77-tf/components/jmeter

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your Proxmox credentials
vim terraform.tfvars
```

**Or use environment variables:**

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

# Deploy JMeter VM
terraform apply

# View outputs
terraform output
```

**Expected output:**
```
jmeter_ssh_command = "ssh a1@192.168.100.23"
jmeter_metrics_endpoint = "http://192.168.100.23:9270/metrics"
```

### 3. Configure with Ansible

After VM deployment, install and configure JMeter with Ansible:

```bash
cd ../../../r77-ansible

# Test connectivity
ansible jmeter -m ping

# Install JMeter and dependencies
ansible-playbook jmeter-setup.yml
```

This will install:
- OpenJDK 17 (JMeter requirement)
- Apache JMeter 5.6.3 (latest version)
- JMeter Prometheus plugin (for Grafana integration)
- Sample test plans and scripts

## JMeter Usage

### Running Load Tests (Non-GUI Mode)

```bash
# SSH to JMeter server
ssh a1@192.168.100.23

# Run a test plan
jmeter -n -t /opt/jmeter-tests/my-test.jmx -l results.jtl

# Run with HTML report generation
jmeter -n -t /opt/jmeter-tests/my-test.jmx -l results.jtl -e -o /opt/jmeter-reports/test-$(date +%Y%m%d-%H%M%S)

# Override thread count and duration
jmeter -n -t test.jmx -l results.jtl -Jusers=100 -Jduration=300
```

### Viewing Results

```bash
# Serve HTML reports via Python
cd /opt/jmeter-reports/test-20241219-143000
python3 -m http.server 8080

# Access in browser
# http://192.168.100.23:8080
```

## Integration with Grafana

JMeter metrics can be sent to your Grafana monitoring stack (192.168.100.21).

### Option 1: Prometheus Plugin (Recommended)

The Ansible playbook installs the Prometheus plugin which exposes metrics at:
```
http://192.168.100.23:9270/metrics
```

Add to Prometheus scrape configuration:
```yaml
# In grafana server: /opt/grafana-stack/prometheus.yml
scrape_configs:
  - job_name: 'jmeter'
    static_configs:
      - targets: ['192.168.100.23:9270']
        labels:
          service: 'jmeter'
          environment: 'testing'
```

Reload Prometheus:
```bash
ssh a1@192.168.100.21
docker exec prometheus kill -HUP 1
```

### Option 2: Backend Listener (InfluxDB)

Configure JMeter Backend Listener in your test plan to send metrics to InfluxDB, then visualize in Grafana.

## Common Operations

### SSH Access

```bash
# Direct SSH
ssh a1@192.168.100.23

# Check JMeter version
ssh a1@192.168.100.23 "jmeter --version"

# List test plans
ssh a1@192.168.100.23 "ls -lh /opt/jmeter-tests/"
```

### Upload Test Plans

```bash
# From your local machine
scp my-test-plan.jmx a1@192.168.100.23:/opt/jmeter-tests/

# Upload multiple files
scp *.jmx a1@192.168.100.23:/opt/jmeter-tests/
```

### Download Results

```bash
# Download results file
scp a1@192.168.100.23:/opt/jmeter-reports/results.jtl ./

# Download entire HTML report directory
scp -r a1@192.168.100.23:/opt/jmeter-reports/test-20241219-143000 ./
```

### Monitor Resource Usage

```bash
# Real-time monitoring
ssh a1@192.168.100.23 "htop"

# Watch JMeter process
ssh a1@192.168.100.23 "watch -n 1 'ps aux | grep jmeter'"

# Check memory usage
ssh a1@192.168.100.23 "free -h"
```

## Best Practices

### 1. Test Plan Design
- **Start small**: Begin with 10-50 users, gradually increase
- **Use realistic think times**: Simulate actual user behavior
- **Parameterize data**: Use CSV files for dynamic test data
- **Enable assertions**: Validate response correctness, not just performance

### 2. Resource Management
- **Monitor RAM usage**: Increase JVM heap if needed (edit `/opt/jmeter/bin/jmeter.sh`)
- **Watch CPU**: If CPU maxes out, consider distributed testing
- **Clean up old results**: Regularly delete old `.jtl` and report files

### 3. Distributed Testing
This server can handle up to 5000 concurrent users in single-server mode. For even higher loads (>5000 users), use distributed mode:

```bash
# On additional JMeter servers, start in server mode
jmeter-server

# On controller (192.168.100.23)
jmeter -n -t test.jmx -R server1:1099,server2:1099 -l results.jtl
```

### 4. JVM Tuning

The Ansible playbook automatically configures optimal JVM settings for 5000 users. Current configuration in `/opt/jmeter/bin/jmeter`:

```bash
# Heap size optimized for 5000 concurrent users
HEAP="-Xms16g -Xmx24g -XX:MaxMetaspaceSize=1g"

# G1GC tuned for large heap
GC_ALGO="-XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=35"
```

**System kernel tuning also applied:**
- Max open files: 1,048,576
- Ephemeral ports: 1024-65535 (64,511 available)
- TCP socket reuse enabled
- Network buffers: 16MB send/receive

## Troubleshooting

### VM Won't Start

```bash
# Check VM status on Proxmox
qm status 123

# View VM console
qm terminal 123

# Check cloud-init logs
ssh a1@192.168.100.23 "sudo cloud-init status --long"
```

### Out of Memory Errors

```bash
# Check JVM heap settings
ssh a1@192.168.100.23 "grep HEAP /opt/jmeter/bin/jmeter"

# Monitor memory during test
ssh a1@192.168.100.23 "watch -n 1 free -h"

# Increase heap size (edit /opt/jmeter/bin/jmeter)
# Change HEAP="-Xms1g -Xmx1g" to HEAP="-Xms4g -Xmx6g"
```

### Test Runs Slowly

Possible causes:
1. **JMeter maxed out**: Check CPU/RAM usage
2. **Network bottleneck**: Test network bandwidth
3. **Target system slow**: The app being tested is the bottleneck (not JMeter)

```bash
# Check JMeter resource usage
ssh a1@192.168.100.23 "top -b -n 1 | grep java"

# Test network speed to target
ssh a1@192.168.100.23 "iperf3 -c target-server"
```

### Results Not Generating

```bash
# Check JMeter log
ssh a1@192.168.100.23 "tail -100 /opt/jmeter/bin/jmeter.log"

# Verify test plan syntax
ssh a1@192.168.100.23 "jmeter -n -t /opt/jmeter-tests/my-test.jmx --validate"

# Run with verbose logging
ssh a1@192.168.100.23 "jmeter -n -t test.jmx -l results.jtl -j jmeter.log -LDEBUG"
```

## Performance Tuning Tips

### Optimize Test Plans
- Disable unnecessary listeners (they consume memory)
- Use CSV datasets instead of hardcoded values
- Minimize assertions (validate samples, not every request)
- Use controllers to organize complex scenarios

### Network Tuning
```bash
# Increase ephemeral port range (for many connections)
sudo sysctl -w net.ipv4.ip_local_port_range="1024 65535"

# Increase max open files
ulimit -n 65536

# Tune TCP settings
sudo sysctl -w net.ipv4.tcp_tw_reuse=1
```

## Example: Load Testing Workflow (5000 Users)

```bash
# 1. Create test plan on desktop with JMeter GUI
# (Save as api-load-test.jmx)

# 2. Upload to JMeter server
scp api-load-test.jmx a1@192.168.100.23:/opt/jmeter-tests/

# 3. SSH to server
ssh a1@192.168.100.23

# 4. Run small test first (verify correctness)
jmeter -n -t /opt/jmeter-tests/api-load-test.jmx -l test-run.jtl -Jusers=10 -Jduration=60

# 5. Review results
cat test-run.jtl | grep false  # Check for errors

# 6. Run gradual ramp-up test (500 users)
jmeter -n -t /opt/jmeter-tests/api-load-test.jmx \
  -l results-500u-$(date +%Y%m%d-%H%M%S).jtl \
  -Jusers=500 \
  -Jrampup=300 \
  -Jduration=900

# 7. Run full load test (5000 users, 30 minutes)
jmeter -n -t /opt/jmeter-tests/api-load-test.jmx \
  -l results-5000u-$(date +%Y%m%d-%H%M%S).jtl \
  -e -o /opt/jmeter-reports/report-5000u-$(date +%Y%m%d-%H%M%S) \
  -Jusers=5000 \
  -Jrampup=600 \
  -Jduration=1800

# 8. Monitor resources during test (in another SSH session)
watch -n 2 'free -h && echo && top -b -n 1 | head -20'

# 9. View report
cd /opt/jmeter-reports/report-5000u-*
python3 -m http.server 8080

# 10. Download results (from local machine)
scp -r a1@192.168.100.23:/opt/jmeter-reports/report-5000u-* ./
```

## Cleanup

### Destroy JMeter VM

```bash
cd r77-tf/components/jmeter
terraform destroy
```

### Remove from Ansible Inventory

Edit `r77-ansible/inventory.yml` and remove the jmeter group.

## References

- [Apache JMeter Documentation](https://jmeter.apache.org/usermanual/)
- [JMeter Best Practices](https://jmeter.apache.org/usermanual/best-practices.html)
- [JMeter Prometheus Plugin](https://github.com/johrstrom/jmeter-prometheus-plugin)
- [Distributed Testing Guide](https://jmeter.apache.org/usermanual/remote-test.html)

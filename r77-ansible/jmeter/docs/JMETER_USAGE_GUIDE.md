# JMeter Load Testing - Complete Usage Guide

This guide walks you through deploying and using the JMeter server for load testing.

## Table of Contents
1. [Quick Start](#quick-start)
2. [Deploy Infrastructure](#deploy-infrastructure)
3. [Run Your First Test](#run-your-first-test)
4. [Understanding Test Results](#understanding-test-results)
5. [Scaling to 5000 Users](#scaling-to-5000-users)
6. [Monitoring with Grafana](#monitoring-with-grafana)
7. [Testing Your Own Application](#testing-your-own-application)
8. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Prerequisites
- Proxmox VE with API access
- Debian 13 template (VMID 998 or 999)
- SSH key at `~/.ssh/vm-deb13.pub`
- Proxmox API credentials

### 5-Minute Setup

```bash
# 1. Set Proxmox credentials
export TF_VAR_proxmox_api_url="https://192.168.100.4:8006"
export TF_VAR_proxmox_api_token_id="root@pam!terraform=your-secret-token"
export TF_VAR_proxmox_tls_insecure=true

# 2. Deploy VM with Terraform
cd r77-tf/components/jmeter
terraform init
terraform apply -auto-approve

# 3. Configure JMeter with Ansible
cd ../../../r77-ansible
ansible jmeter -m ping  # Test connectivity
ansible-playbook jmeter-setup.yml

# 4. Upload sample test
scp jmeter-sample-test.jmx a1@192.168.100.23:/opt/jmeter-tests/

# 5. Run first test
ssh a1@192.168.100.23
jmeter -n -t /opt/jmeter-tests/jmeter-sample-test.jmx -l results.jtl
```

---

## Deploy Infrastructure

### Step 1: Deploy JMeter VM with Terraform

```bash
cd r77-tf/components/jmeter

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy the VM (16 CPU, 32GB RAM, 80GB disk)
terraform apply

# Note the outputs
terraform output
```

**Expected output:**
```
jmeter_vm_id = 123
jmeter_hostname = "jmeter"
jmeter_ip = "192.168.100.23"
jmeter_ssh_command = "ssh a1@192.168.100.23"
jmeter_metrics_endpoint = "http://192.168.100.23:9270/metrics"
```

### Step 2: Install JMeter with Ansible

```bash
cd ../../../r77-ansible

# Test connectivity
ansible jmeter -m ping

# Install and configure JMeter
ansible-playbook jmeter-setup.yml
```

**What gets installed:**
- ✅ OpenJDK (latest available)
- ✅ Apache JMeter 5.6.3
- ✅ JMeter Prometheus Plugin 0.6.0
- ✅ JVM tuning (16GB-24GB heap)
- ✅ System tuning (1M file descriptors, 64K ports)
- ✅ Sample test plans
- ✅ Helper scripts

**Installation takes ~5-10 minutes**

---

## Run Your First Test

### Understanding the Sample Test

The included `jmeter-sample-test.jmx` is a simple HTTP load test that:
- Sends GET requests to `http://httpbin.org/get`
- Sends POST requests to `http://httpbin.org/post`
- Validates HTTP 200 responses
- Uses realistic 1-second think time between requests
- Exposes metrics on port 9270 for Prometheus

### Upload Sample Test to JMeter Server

```bash
# From your local machine
cd r77-ansible
scp jmeter-sample-test.jmx a1@192.168.100.23:/opt/jmeter-tests/
```

### Run the Test - Small Load (10 users)

```bash
# SSH to JMeter server
ssh a1@192.168.100.23

# Run test with 10 users for 60 seconds
jmeter -n \
  -t /opt/jmeter-tests/jmeter-sample-test.jmx \
  -l /opt/jmeter-results/results-$(date +%Y%m%d-%H%M%S).jtl \
  -Jusers=10 \
  -Jrampup=5 \
  -Jduration=60
```

**Command breakdown:**
- `-n`: Non-GUI mode (headless)
- `-t`: Test plan file
- `-l`: Results log file (.jtl format)
- `-Jusers=10`: Override NUM_USERS variable (10 concurrent users)
- `-Jrampup=5`: Ramp up users over 5 seconds
- `-Jduration=60`: Run test for 60 seconds

### Generate HTML Report

```bash
# Run test with HTML report generation
jmeter -n \
  -t /opt/jmeter-tests/jmeter-sample-test.jmx \
  -l /opt/jmeter-results/results-$(date +%Y%m%d-%H%M%S).jtl \
  -e -o /opt/jmeter-reports/report-$(date +%Y%m%d-%H%M%S) \
  -Jusers=10 \
  -Jrampup=5 \
  -Jduration=60
```

**New parameters:**
- `-e`: Generate HTML dashboard report after test
- `-o`: Output directory for HTML report

### View HTML Report

```bash
# Start HTTP server to view report
cd /opt/jmeter-reports/report-*
python3 -m http.server 8080
```

**Access in browser:** `http://192.168.100.23:8080`

**Download report to your machine:**
```bash
# From your local machine
scp -r a1@192.168.100.23:/opt/jmeter-reports/report-* ./jmeter-reports/
```

---

## Understanding Test Results

### Real-Time Monitoring During Test

Open a second SSH session while test is running:

```bash
# Terminal 1 - Run test
ssh a1@192.168.100.23
jmeter -n -t /opt/jmeter-tests/jmeter-sample-test.jmx -l results.jtl -Jusers=100 -Jduration=300

# Terminal 2 - Monitor resources
ssh a1@192.168.100.23
watch -n 2 'free -h && echo "---" && top -b -n 1 | head -15'
```

### Analyzing .jtl Results File

```bash
# Quick stats
cat results.jtl | tail -100

# Count total requests
cat results.jtl | grep -c "^[0-9]"

# Count errors (false = failed assertion)
cat results.jtl | grep -c "false"

# Average response time (requires awk)
awk -F',' '{sum+=$2; count++} END {print "Avg Response Time: " sum/count " ms"}' results.jtl
```

### Key Metrics in HTML Report

When you open the HTML report, focus on these sections:

**1. Dashboard**
- Requests/sec (throughput)
- Response times (median, 90th, 95th, 99th percentile)
- Error rate (should be 0%)

**2. Response Times Over Time**
- Should be relatively stable
- Spikes indicate issues with target server or network

**3. Active Threads Over Time**
- Should show smooth ramp-up
- Plateau at max users

**4. Transactions Per Second**
- Higher is better
- Should be consistent during plateau

---

## Scaling to 5000 Users

### Gradual Load Testing Approach

**Never jump directly to 5000 users!** Follow this progression:

#### Phase 1: Baseline (10 users, 60 seconds)
```bash
jmeter -n -t /opt/jmeter-tests/jmeter-sample-test.jmx \
  -l results-10u.jtl \
  -e -o /opt/jmeter-reports/report-10u \
  -Jusers=10 -Jrampup=5 -Jduration=60
```
**Goal:** Verify test plan works correctly, no errors

#### Phase 2: Small Load (100 users, 5 minutes)
```bash
jmeter -n -t /opt/jmeter-tests/jmeter-sample-test.jmx \
  -l results-100u.jtl \
  -e -o /opt/jmeter-reports/report-100u \
  -Jusers=100 -Jrampup=30 -Jduration=300
```
**Goal:** Establish baseline performance metrics

#### Phase 3: Medium Load (500 users, 10 minutes)
```bash
jmeter -n -t /opt/jmeter-tests/jmeter-sample-test.jmx \
  -l results-500u.jtl \
  -e -o /opt/jmeter-reports/report-500u \
  -Jusers=500 -Jrampup=120 -Jduration=600
```
**Goal:** Monitor JMeter server resource usage (CPU, RAM)

#### Phase 4: High Load (2500 users, 15 minutes)
```bash
jmeter -n -t /opt/jmeter-tests/jmeter-sample-test.jmx \
  -l results-2500u.jtl \
  -e -o /opt/jmeter-reports/report-2500u \
  -Jusers=2500 -Jrampup=300 -Jduration=900
```
**Goal:** Check if JMeter or target server is bottleneck

#### Phase 5: Full Load (5000 users, 30 minutes)
```bash
jmeter -n -t /opt/jmeter-tests/jmeter-sample-test.jmx \
  -l results-5000u.jtl \
  -e -o /opt/jmeter-reports/report-5000u \
  -Jusers=5000 -Jrampup=600 -Jduration=1800
```
**Goal:** Production-scale load test

### Monitoring JMeter Server During 5000 User Test

```bash
# Terminal 1 - Run test
jmeter -n -t test.jmx -l results.jtl -Jusers=5000 -Jrampup=600 -Jduration=1800

# Terminal 2 - Monitor
htop  # Press F5 for tree view, watch Java process

# Terminal 3 - Track metrics
watch -n 5 'echo "=== Memory ==="; free -h; echo "=== Connections ==="; ss -s'
```

**What to watch for:**
- ✅ CPU usage: 60-80% is optimal (16 cores should handle it)
- ✅ Memory: JVM should use 16-24GB (check with `free -h`)
- ✅ Network: Monitor with `iftop` or `nethogs`
- ⚠️ If CPU hits 100% → JMeter is the bottleneck
- ⚠️ If CPU is low but response times are high → Target server is bottleneck

---

## Monitoring with Grafana

### Add JMeter to Prometheus

The JMeter server exposes metrics at `http://192.168.100.23:9270/metrics`

#### Step 1: Configure Prometheus on Grafana Server

```bash
# SSH to Grafana server
ssh a1@192.168.100.21

# Edit Prometheus config
cd /opt/grafana-stack
vim prometheus.yml
```

Add this to the `scrape_configs` section:

```yaml
scrape_configs:
  # ... existing configs ...

  - job_name: 'jmeter'
    scrape_interval: 5s  # Scrape every 5 seconds during tests
    static_configs:
      - targets: ['192.168.100.23:9270']
        labels:
          service: 'jmeter'
          environment: 'load-testing'
```

#### Step 2: Reload Prometheus Configuration

```bash
# Reload without restarting (no downtime!)
docker exec prometheus kill -HUP 1

# Verify JMeter target is being scraped
docker logs prometheus | grep jmeter
```

#### Step 3: Verify Metrics in Prometheus

Open Prometheus UI: `http://192.168.100.21:9090`

Run these queries:
- `jmeter_threads_total` - Active threads (users)
- `rate(jmeter_requests_total[1m])` - Requests per second
- `jmeter_response_time_seconds` - Response times
- `rate(jmeter_errors_total[1m])` - Error rate

#### Step 4: Create Grafana Dashboard

1. Open Grafana: `http://192.168.100.21:3000`
2. Login (admin/admin)
3. Create new dashboard
4. Add panels with these queries:

**Panel 1: Active Users**
```promql
jmeter_threads_total
```

**Panel 2: Throughput (req/sec)**
```promql
rate(jmeter_requests_total[1m])
```

**Panel 3: Average Response Time**
```promql
jmeter_response_time_seconds_avg
```

**Panel 4: Error Rate**
```promql
rate(jmeter_errors_total[1m])
```

---

## Testing Your Own Application

### Modify the Sample Test for Your App

```bash
# Download sample test to your machine
scp a1@192.168.100.23:/opt/jmeter-tests/jmeter-sample-test.jmx ./my-app-test.jmx

# Edit with your favorite editor
vim my-app-test.jmx

# Or use JMeter GUI on your desktop
jmeter  # Opens GUI
# File > Open > my-app-test.jmx
# Modify HTTP requests to point to your app
# File > Save
```

### Key Changes to Make

**1. Update Target Host**
Change `TARGET_HOST` default value:
```xml
<stringProp name="Argument.value">${__P(target,httpbin.org)}</stringProp>
```
To:
```xml
<stringProp name="Argument.value">${__P(target,your-app.com)}</stringProp>
```

**2. Update Paths**
Modify HTTP request paths to match your API:
```xml
<stringProp name="HTTPSampler.path">/api/your-endpoint</stringProp>
```

**3. Add Authentication**
Add HTTP Header Manager with your auth token:
```xml
<HeaderManager>
  <elementProp name="Authorization">
    <stringProp name="Header.name">Authorization</stringProp>
    <stringProp name="Header.value">Bearer ${AUTH_TOKEN}</stringProp>
  </elementProp>
</HeaderManager>
```

**4. Update Assertions**
Modify response code assertions if needed:
```xml
<stringProp name="49586">200</stringProp>  <!-- Change to expected code -->
```

### Upload and Test

```bash
# Upload modified test
scp my-app-test.jmx a1@192.168.100.23:/opt/jmeter-tests/

# Run with custom parameters
ssh a1@192.168.100.23
jmeter -n \
  -t /opt/jmeter-tests/my-app-test.jmx \
  -l results.jtl \
  -Jtarget=your-app.com \
  -Jport=443 \
  -Jusers=50 \
  -Jduration=300
```

### Testing Internal Applications

If your app is on the same network (192.168.100.x):

```bash
jmeter -n \
  -t test.jmx \
  -l results.jtl \
  -Jtarget=192.168.100.50 \
  -Jport=8080 \
  -Jusers=500 \
  -Jduration=600
```

---

## Troubleshooting

### Test Won't Start

**Error: "Could not find test plan file"**
```bash
# Check file exists
ls -lh /opt/jmeter-tests/

# Check file permissions
chmod 644 /opt/jmeter-tests/*.jmx
```

**Error: "Out of memory"**
```bash
# Check current heap settings
grep HEAP /opt/jmeter/bin/jmeter

# Should show: HEAP="-Xms16g -Xmx24g -XX:MaxMetaspaceSize=1g"
# If not, re-run Ansible playbook
```

### High Error Rate During Test

**Check JMeter logs:**
```bash
tail -100 /opt/jmeter/bin/jmeter.log
```

**Common causes:**
- Target server is down or unreachable
- Wrong hostname/IP in test plan
- Authentication required but not provided
- Firewall blocking connections
- Target server can't handle the load

**Verify connectivity:**
```bash
# From JMeter server
curl -v http://your-target-app.com
```

### Slow Response Times

**Is JMeter the bottleneck?**
```bash
# Check JMeter CPU usage
top -p $(pgrep -f jmeter)

# If CPU is 100% across all cores → JMeter is maxed out
# If CPU is low → Target server is slow
```

**Is network the bottleneck?**
```bash
# Test network speed to target
iperf3 -c target-server

# Check for packet loss
ping -c 100 target-server | grep loss
```

### Results File is Huge

Large .jtl files (>1GB) can slow down report generation.

**Solution: Reduce captured data**
```bash
# Edit jmeter.properties
vim /opt/jmeter/bin/jmeter.properties

# Set these to false:
jmeter.save.saveservice.response_data=false
jmeter.save.saveservice.samplerData=false
```

### Can't Access HTML Reports

**Check if HTTP server is running:**
```bash
ss -tulpn | grep 8080
```

**Check firewall:**
```bash
sudo ufw status
sudo ufw allow 8080/tcp
```

**Alternative: Download reports locally**
```bash
scp -r a1@192.168.100.23:/opt/jmeter-reports/report-* ./
cd report-*
python3 -m http.server 8080
# Open http://localhost:8080
```

### Prometheus Metrics Not Showing

**Check if port 9270 is open:**
```bash
# On JMeter server
sudo ufw status | grep 9270
sudo ufw allow 9270/tcp

# Test from Grafana server
curl http://192.168.100.23:9270/metrics
```

**Verify Prometheus scraping:**
```bash
# On Grafana server
docker logs prometheus | grep jmeter

# Check Prometheus targets
# Open http://192.168.100.21:9090/targets
# JMeter target should show "UP"
```

---

## Helper Commands Reference

### Quick Test Execution

```bash
# Small test (10 users, 1 minute)
jmeter-run /opt/jmeter-tests/jmeter-sample-test.jmx 10 60

# Medium test (100 users, 5 minutes)
jmeter-run /opt/jmeter-tests/jmeter-sample-test.jmx 100 300

# Large test (500 users, 10 minutes)
jmeter-run /opt/jmeter-tests/jmeter-sample-test.jmx 500 600
```

### Check JMeter Version
```bash
jmeter --version
```

### List Running Tests
```bash
ps aux | grep jmeter
```

### Kill Running Test
```bash
pkill -f jmeter
```

### Clean Up Old Results
```bash
# Remove results older than 7 days
find /opt/jmeter-results/ -type f -mtime +7 -delete
find /opt/jmeter-reports/ -type d -mtime +7 -exec rm -rf {} +
```

### Check Disk Space
```bash
df -h /opt/jmeter-results/
df -h /opt/jmeter-reports/
```

---

## Next Steps

1. **Run the sample test** to verify everything works
2. **Create your own test plan** for your application
3. **Start small** (10-50 users) and gradually increase
4. **Monitor with Grafana** for real-time insights
5. **Analyze HTML reports** to find performance bottlenecks
6. **Iterate and optimize** your application based on findings

For more advanced usage, see:
- [JMeter Documentation](https://jmeter.apache.org/usermanual/)
- [JMeter Best Practices](https://jmeter.apache.org/usermanual/best-practices.html)
- [Component README](../r77-tf/components/jmeter/README.md)

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Run test | `jmeter -n -t test.jmx -l results.jtl -Jusers=10 -Jduration=60` |
| Generate report | `jmeter -n -t test.jmx -l results.jtl -e -o report/` |
| View report | `cd report/ && python3 -m http.server 8080` |
| Check version | `jmeter --version` |
| Monitor CPU/RAM | `htop` |
| View logs | `tail -f /opt/jmeter/bin/jmeter.log` |
| Kill test | `pkill -f jmeter` |
| Upload test plan | `scp test.jmx a1@192.168.100.23:/opt/jmeter-tests/` |
| Download results | `scp a1@192.168.100.23:/opt/jmeter-results/results.jtl ./` |

---

**Happy Load Testing! 🚀**

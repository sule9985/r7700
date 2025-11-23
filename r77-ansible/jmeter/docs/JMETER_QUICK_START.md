# JMeter Quick Start - 5 Minute Guide

## 1️⃣ Deploy (One Time Setup)

```bash
# Set credentials
export TF_VAR_proxmox_api_url="https://192.168.100.4:8006"
export TF_VAR_proxmox_api_token_id="root@pam!terraform=your-token"
export TF_VAR_proxmox_tls_insecure=true

# Deploy VM
cd r77-tf/components/jmeter
terraform init && terraform apply

# Install JMeter
cd ../../../r77-ansible
ansible-playbook jmeter-setup.yml

# Upload sample test
scp jmeter-sample-test.jmx a1@192.168.100.23:/opt/jmeter-tests/
```

## 2️⃣ Run Your First Test

```bash
# SSH to JMeter server
ssh a1@192.168.100.23

# Run test: 10 users for 60 seconds
jmeter -n \
  -t /opt/jmeter-tests/jmeter-sample-test.jmx \
  -l results.jtl \
  -Jusers=10 \
  -Jrampup=5 \
  -Jduration=60
```

## 3️⃣ View Results

```bash
# Generate HTML report
jmeter -n \
  -t /opt/jmeter-tests/jmeter-sample-test.jmx \
  -l results.jtl \
  -e -o /opt/jmeter-reports/report-$(date +%Y%m%d-%H%M%S) \
  -Jusers=10 -Jduration=60

# View in browser
cd /opt/jmeter-reports/report-*
python3 -m http.server 8080

# Open: http://192.168.100.23:8080
```

## 4️⃣ Scale Up Gradually

```bash
# Phase 1: 10 users (baseline)
jmeter-run /opt/jmeter-tests/jmeter-sample-test.jmx 10 60

# Phase 2: 100 users (small load)
jmeter-run /opt/jmeter-tests/jmeter-sample-test.jmx 100 300

# Phase 3: 500 users (medium load)
jmeter-run /opt/jmeter-tests/jmeter-sample-test.jmx 500 600

# Phase 4: 2500 users (high load)
jmeter -n -t /opt/jmeter-tests/jmeter-sample-test.jmx \
  -l results.jtl -e -o report-2500u \
  -Jusers=2500 -Jrampup=300 -Jduration=900

# Phase 5: 5000 users (max load)
jmeter -n -t /opt/jmeter-tests/jmeter-sample-test.jmx \
  -l results.jtl -e -o report-5000u \
  -Jusers=5000 -Jrampup=600 -Jduration=1800
```

## 5️⃣ Test Your Own App

```bash
# Method 1: Command line override
jmeter -n -t /opt/jmeter-tests/jmeter-sample-test.jmx \
  -l results.jtl \
  -Jtarget=your-app.com \
  -Jport=443 \
  -Jusers=50 \
  -Jduration=300

# Method 2: Edit test plan (recommended)
# Download sample, edit with JMeter GUI, re-upload
scp a1@192.168.100.23:/opt/jmeter-tests/jmeter-sample-test.jmx ./
# Edit with JMeter GUI (on your desktop)
scp my-app-test.jmx a1@192.168.100.23:/opt/jmeter-tests/
```

## 6️⃣ Monitor with Grafana

```bash
# On Grafana server (192.168.100.21)
ssh a1@192.168.100.21
cd /opt/grafana-stack
vim prometheus.yml
```

Add:
```yaml
scrape_configs:
  - job_name: 'jmeter'
    scrape_interval: 5s
    static_configs:
      - targets: ['192.168.100.23:9270']
```

Reload:
```bash
docker exec prometheus kill -HUP 1
```

View metrics: `http://192.168.100.21:9090`

## 📊 Sample Test Details

**What it tests:**
- HTTP GET requests to `httpbin.org/get`
- HTTP POST requests to `httpbin.org/post`
- Validates HTTP 200 responses
- 1-second think time between requests

**Configurable parameters:**
- `target` - Hostname (default: httpbin.org)
- `port` - Port (default: 80)
- `users` - Concurrent users (default: 10)
- `rampup` - Ramp-up time in seconds (default: 10)
- `duration` - Test duration in seconds (default: 60)

## 🔧 Useful Commands

```bash
# Check JMeter version
jmeter --version

# Monitor resources during test
htop

# View real-time logs
tail -f /opt/jmeter/bin/jmeter.log

# Kill running test
pkill -f jmeter

# Download report to local machine
scp -r a1@192.168.100.23:/opt/jmeter-reports/report-* ./

# Clean old results (7+ days)
find /opt/jmeter-results/ -type f -mtime +7 -delete
```

## 🎯 Recommended Test Progression

| Users | Duration | Purpose | Expected RPS* |
|-------|----------|---------|--------------|
| 10 | 1 min | Verify test works | ~10-20 |
| 100 | 5 min | Baseline performance | ~100-200 |
| 500 | 10 min | Monitor JMeter usage | ~500-1000 |
| 2500 | 15 min | Check scalability | ~2500-5000 |
| 5000 | 30 min | Production load | ~5000-10000 |

*RPS = Requests per second (depends on target server performance)

## ⚠️ Important Notes

1. **Never jump to 5000 users** - Always start small and increase gradually
2. **Monitor JMeter resources** - Watch CPU/RAM during large tests
3. **Monitor target server** - High response times may indicate server bottleneck
4. **Use Grafana** - Real-time metrics are better than post-test analysis
5. **Stop VM when done** - Save resources by shutting down JMeter VM

## 📚 Full Documentation

- Detailed guide: `JMETER_USAGE_GUIDE.md`
- Component docs: `../r77-tf/components/jmeter/README.md`
- Official JMeter: https://jmeter.apache.org/usermanual/

## 🆘 Troubleshooting

**Test fails immediately:**
```bash
# Check connectivity to target
curl -v http://target-server.com
```

**Metrics not showing in Grafana:**
```bash
# Test Prometheus endpoint
curl http://192.168.100.23:9270/metrics

# Check firewall
sudo ufw allow 9270/tcp
```

**Out of memory:**
```bash
# Verify JVM heap settings
grep HEAP /opt/jmeter/bin/jmeter
# Should show: HEAP="-Xms16g -Xmx24g ..."
```

---

**Ready to start? Run step 1️⃣ now!**

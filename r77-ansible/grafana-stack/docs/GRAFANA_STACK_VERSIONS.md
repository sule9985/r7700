# Grafana Stack Component Versions

This document tracks the versions of all monitoring stack components.

## Current Versions (as of 2025-01-22)

| Component | Version | Release Date | Notes |
|-----------|---------|--------------|-------|
| **Grafana** | 12.3.0 | 2025 | Installed via APT repository |
| **Prometheus** | 3.7.3 | 2025 | Binary from GitHub releases |
| **Loki** | 3.6.0 | 2025 | Binary from GitHub releases |
| **AlertManager** | 0.29.0 | 2025 | Binary from GitHub releases |
| **Proxmox PVE Exporter** | latest | - | Installed via pip3 |

## Download URLs

### Prometheus 3.7.3
- **Linux AMD64**: https://github.com/prometheus/prometheus/releases/download/v3.7.3/prometheus-3.7.3.linux-amd64.tar.gz
- **Darwin AMD64**: https://github.com/prometheus/prometheus/releases/download/v3.7.3/prometheus-3.7.3.darwin-amd64.tar.gz

### Loki 3.6.0
- **Linux AMD64**: https://github.com/grafana/loki/releases/download/v3.6.0/loki-linux-amd64.zip
- **Darwin AMD64**: https://github.com/grafana/loki/releases/download/v3.6.0/loki-darwin-amd64.zip

### AlertManager 0.29.0
- **Linux AMD64**: https://github.com/prometheus/alertmanager/releases/download/v0.29.0/alertmanager-0.29.0.linux-amd64.tar.gz
- **Darwin AMD64**: https://github.com/prometheus/alertmanager/releases/download/v0.29.0/alertmanager-0.29.0.darwin-amd64.tar.gz

### Grafana 12.3.0
- **APT Repository**: https://apt.grafana.com
- Package name: `grafana=12.3.0`

### Prometheus PVE Exporter
- **PyPI**: https://pypi.org/project/prometheus-pve-exporter/
- **GitHub**: https://github.com/prometheus-pve/prometheus-pve-exporter
- Install: `pip3 install prometheus-pve-exporter`

## Version Compatibility

| Component | Minimum Compatible Version |
|-----------|----------------------------|
| Debian | 12+ (Bookworm or Trixie) |
| Python | 3.9+ |
| Proxmox VE | 7.0+ |

## Updating Versions

To update component versions, edit the following files:

### Ansible Playbook
File: `r77-ansible/grafana-stack-setup.yml`

```yaml
vars:
  grafana_version: "12.3.0"
  prometheus_version: "3.7.3"
  loki_version: "3.6.0"
  alertmanager_version: "0.29.0"
```

### Documentation
1. `r77-ansible/GRAFANA_STACK_DEPLOYMENT.md` - Line 117-121
2. `r77-tf/components/grafana-stack/README.md` - Line 7-11
3. This file (`GRAFANA_STACK_VERSIONS.md`) - Update table above

## Upgrade Procedure

### To upgrade an existing installation:

1. **Update version variables** in `grafana-stack-setup.yml`

2. **Re-run the Ansible playbook**:
   ```bash
   cd r77-ansible
   ansible-playbook grafana-stack-setup.yml
   ```

3. **Verify services are running**:
   ```bash
   ssh root@192.168.100.40
   systemctl status grafana-server prometheus loki alertmanager
   ```

4. **Check versions**:
   ```bash
   # Grafana
   grafana-cli --version

   # Prometheus
   /usr/local/bin/prometheus --version

   # Loki
   /usr/local/bin/loki --version

   # AlertManager
   /usr/local/bin/alertmanager --version

   # PVE Exporter
   pip3 show prometheus-pve-exporter
   ```

## Known Issues

### Grafana 12.3.0
- No known issues

### Prometheus 3.7.3
- **Breaking change from 2.x**: New OTLP (OpenTelemetry) receiver enabled by default
- Configuration syntax is backward compatible
- Storage format is compatible with 2.x

### Loki 3.6.0
- **Schema update**: Uses TSDB format (v13 schema)
- Configuration requires explicit schema_config
- Retention settings moved to limits_config

### AlertManager 0.29.0
- No major breaking changes from 0.27.x

## Version History

| Date | Component | Old Version | New Version | Reason |
|------|-----------|-------------|-------------|--------|
| 2025-01-22 | All | Initial | See above | Initial deployment with latest versions |

## Rollback Procedure

If an upgrade causes issues:

1. **Restore from LXC snapshot**:
   ```bash
   # On Proxmox host
   pct listsnapshot 140
   pct rollback 140 <snapshot-name>
   pct start 140
   ```

2. **Or manually downgrade**:
   ```bash
   # Update version in grafana-stack-setup.yml
   # Re-run playbook
   ansible-playbook grafana-stack-setup.yml
   ```

## Testing New Versions

Before deploying to production:

1. Create a test LXC container (VMID 141)
2. Update version in playbook
3. Deploy to test container
4. Verify all services work
5. Test data ingestion and querying
6. If successful, deploy to production (VMID 140)

## Release Monitoring

Check for new releases:
- Grafana: https://github.com/grafana/grafana/releases
- Prometheus: https://github.com/prometheus/prometheus/releases
- Loki: https://github.com/grafana/loki/releases
- AlertManager: https://github.com/prometheus/alertmanager/releases
- PVE Exporter: https://github.com/prometheus-pve/prometheus-pve-exporter/releases

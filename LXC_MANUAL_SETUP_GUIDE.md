# LXC Container Manual Setup Guide

A comprehensive guide to manually creating and configuring LXC containers in Proxmox VE.

## Table of Contents

1. [Understanding LXC Containers](#understanding-lxc-containers)
2. [Privileged vs Unprivileged Containers](#privileged-vs-unprivileged-containers)
3. [Prerequisites](#prerequisites)
4. [Manual Container Creation](#manual-container-creation)
5. [Network Configuration](#network-configuration)
6. [SSH Access Setup](#ssh-access-setup)
7. [Storage Management](#storage-management)
8. [Troubleshooting](#troubleshooting)

---

## Understanding LXC Containers

### What is LXC?

**LXC (Linux Containers)** is an operating system-level virtualization method that allows multiple isolated Linux systems (containers) to run on a single host using the same kernel.

**Key Differences from VMs:**

| Feature | LXC Container | Virtual Machine (VM) |
|---------|---------------|---------------------|
| **Kernel** | Shares host kernel | Has own kernel |
| **Boot Time** | Seconds | Minutes |
| **Resource Usage** | Very low overhead | Higher overhead |
| **Isolation** | Process-level | Hardware-level |
| **Size** | MBs to GBs | GBs to TBs |
| **Use Case** | Services, apps | Full OS instances |

**When to Use LXC:**
- ✅ Running services (web servers, databases, monitoring)
- ✅ Development environments
- ✅ Microservices architecture
- ✅ Resource-efficient deployments

**When to Use VMs:**
- ✅ Running different operating systems (Windows on Linux host)
- ✅ Maximum isolation required
- ✅ Kernel-level customization needed
- ✅ Legacy applications

---

## Privileged vs Unprivileged Containers

### Privileged Containers

**Definition:** Container's root user (UID 0) = Host's root user (UID 0)

**Characteristics:**
- 🔴 **Security Risk:** Root in container = root on host
- ✅ Full hardware access
- ✅ Can mount file systems
- ✅ Can load kernel modules
- ⚠️ If compromised, attacker has root on host

**Use Cases:**
- Docker host (needs nested virtualization)
- NFS mounts with specific UID/GID requirements
- Legacy applications requiring root privileges

**Example Configuration:**
```bash
# Privileged container
unprivileged: 0  # In Proxmox UI or config
```

### Unprivileged Containers (Recommended)

**Definition:** Container's UIDs/GIDs are **mapped** to different UIDs/GIDs on the host

**UID/GID Mapping Example:**

| Container | Host | Description |
|-----------|------|-------------|
| UID 0 (root) | UID 100000 | Container root ≠ Host root |
| UID 1 | UID 100001 | First user |
| UID 1000 | UID 101000 | Regular user |

**Characteristics:**
- ✅ **Much More Secure:** Root in container ≠ root on host
- ✅ Container escape = unprivileged user on host
- ✅ Recommended by Proxmox and security best practices
- ⚠️ Cannot mount certain file systems
- ⚠️ Some apps may have permission issues

**Use Cases:**
- Web servers (nginx, Apache)
- Application servers (Node.js, Python)
- Monitoring stacks (Grafana, Prometheus)
- **Most production workloads**

**Example Configuration:**
```bash
# Unprivileged container (default and recommended)
unprivileged: 1
```

### Security Comparison

```
┌─────────────────────────────────────────────────────────┐
│ PRIVILEGED CONTAINER                                     │
├─────────────────────────────────────────────────────────┤
│ Container:  root (UID 0)                                │
│                  ↓                                        │
│ Host:       root (UID 0)  ← SECURITY RISK!              │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ UNPRIVILEGED CONTAINER                                   │
├─────────────────────────────────────────────────────────┤
│ Container:  root (UID 0)                                │
│                  ↓                                        │
│ Host:       user (UID 100000)  ← SECURE!                │
└─────────────────────────────────────────────────────────┘
```

**Recommendation:** Always use **unprivileged containers** unless you have a specific requirement for privileged mode.

---

## Prerequisites

### 1. Download LXC Templates

LXC containers are created from **templates** (pre-built root filesystems).

```bash
# SSH to Proxmox host
ssh root@192.168.100.4

# Update template list
pveam update

# List available templates
pveam available

# Common templates:
# - debian-13-standard_13.1-2_amd64.tar.zst  (Debian 13 - Latest)
# - ubuntu-24.04-standard_24.04-2_amd64.tar.zst
# - alpine-3.19-default_20240207_amd64.tar.xz  (Minimal)

# Download Debian 13 template
pveam download local debian-13-standard_13.1-2_amd64.tar.zst

# Verify download
pveam list local
```

**Template Storage Locations:**
- Default: `/var/lib/vz/template/cache/`
- Custom storage: Check Proxmox datacenter storage settings

### 2. Plan Your Container

Before creating, decide:

| Parameter | Example | Notes |
|-----------|---------|-------|
| **VMID** | 140 | Unique ID (100-999999) |
| **Hostname** | grafana-stack | DNS-friendly name |
| **IP Address** | 192.168.100.40/24 | Static or DHCP |
| **Gateway** | 192.168.100.1 | Network gateway |
| **CPU Cores** | 4 | Number of cores |
| **Memory** | 8192 MB | RAM in MB |
| **Swap** | 2048 MB | Swap space |
| **Root Disk** | 60 GB | Root filesystem size |
| **Storage** | local-zfs | Proxmox storage pool |

---

## Manual Container Creation

### Method 1: Proxmox Web UI

#### Step 1: Create Container

1. **Open Proxmox Web UI**: https://192.168.100.4:8006
2. **Click**: Datacenter → Your Node (e.g., "pve")
3. **Click**: "Create CT" (top right)

#### Step 2: General Tab

| Field | Value | Description |
|-------|-------|-------------|
| **Node** | pve | Proxmox node |
| **CT ID** | 140 | Container ID |
| **Hostname** | grafana-stack | Container hostname |
| **Unprivileged container** | ✅ Checked | Use unprivileged (secure) |
| **Nesting** | ☐ Unchecked | Only for Docker/nested containers |
| **Resource Pool** | - | Optional grouping |
| **Password** | (set password) | Root password (temporary) |
| **SSH public key** | (paste key) | Your SSH public key |

**Important:**
- ✅ Always check "Unprivileged container"
- ✅ Add SSH key here if you have one ready

#### Step 3: Template Tab

| Field | Value |
|-------|-------|
| **Storage** | local |
| **Template** | debian-13-standard_13.1-2_amd64.tar.zst |

#### Step 4: Root Disk Tab

| Field | Value | Notes |
|-------|-------|-------|
| **Storage** | local-zfs | ZFS recommended |
| **Disk size (GiB)** | 60 | Can expand later |

#### Step 5: CPU Tab

| Field | Value | Notes |
|-------|-------|-------|
| **Cores** | 4 | Allocated CPU cores |
| **CPU limit** | - | Optional CPU limit |
| **CPU units** | 1024 | Relative CPU weight |

#### Step 6: Memory Tab

| Field | Value | Notes |
|-------|-------|-------|
| **Memory (MiB)** | 8192 | 8 GB RAM |
| **Swap (MiB)** | 2048 | 2 GB swap |

#### Step 7: Network Tab

**DHCP Configuration:**

| Field | Value |
|-------|-------|
| **Bridge** | vmbr0 |
| **IPv4** | DHCP |
| **IPv6** | DHCP (or leave blank) |

**Static IP Configuration:**

| Field | Value | Example |
|-------|-------|---------|
| **Bridge** | vmbr0 | Default bridge |
| **IPv4** | Static | - |
| **IPv4/CIDR** | 192.168.100.40/24 | IP with netmask |
| **Gateway (IPv4)** | 192.168.100.1 | Your gateway |
| **IPv6** | - | Leave blank if not used |

#### Step 8: DNS Tab

| Field | Value | Notes |
|-------|-------|-------|
| **DNS domain** | local | Optional |
| **DNS servers** | 8.8.8.8, 8.8.4.4 | Google DNS |

#### Step 9: Confirm

- Review all settings
- Click **Finish**
- Container will be created (takes 10-30 seconds)

#### Step 10: Start Container

1. **Select container** in left sidebar (ID 140)
2. **Click** "Start" button
3. **Wait** for status to show "running"

---

### Method 2: Command Line (pct)

```bash
# SSH to Proxmox host
ssh root@192.168.100.4

# Create container with all parameters
pct create 140 \
  local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname grafana-stack \
  --cores 4 \
  --memory 8192 \
  --swap 2048 \
  --rootfs local-zfs:60 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.100.40/24,gw=192.168.100.1 \
  --nameserver 8.8.8.8 \
  --nameserver 8.8.4.4 \
  --unprivileged 1 \
  --onboot 1 \
  --start 1 \
  --ssh-public-keys /root/.ssh/authorized_keys

# Explanation of parameters:
# 140                    - Container ID
# local:vztmpl/...       - Template storage:path
# --hostname             - Container hostname
# --cores                - CPU cores
# --memory               - RAM in MB
# --swap                 - Swap in MB
# --rootfs               - Root filesystem (storage:size)
# --net0                 - Network config (name,bridge,ip,gateway)
# --nameserver           - DNS servers
# --unprivileged 1       - Unprivileged container (secure)
# --onboot 1             - Start on boot
# --start 1              - Start immediately after creation
# --ssh-public-keys      - Path to SSH public keys on Proxmox host
```

**Verify Container:**

```bash
# Check status
pct status 140

# View configuration
pct config 140

# List all containers
pct list
```

---

## Network Configuration

### Understanding LXC Networking

LXC containers don't use cloud-init like VMs. Network configuration is done via:
1. **Proxmox configuration** (sets up bridge)
2. **Container's /etc/network/interfaces** (needs manual config in some cases)

### Problem: Network Interface DOWN

When you create an LXC container with Proxmox, sometimes the network interface doesn't come up automatically, especially with Debian 13 templates.

**Check Network Status:**

```bash
# Enter container console
pct enter 140

# Check network interfaces
ip addr show

# Common issue: eth0 shows "state DOWN"
# 2: eth0@if20: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN
```

### Solution 1: Configure Network Interface (Manual)

```bash
# Enter container
pct enter 140

# Create/edit network configuration
cat > /etc/network/interfaces << 'EOF'
# Loopback interface
auto lo
iface lo inet loopback

# Primary network interface
auto eth0
iface eth0 inet static
    address 192.168.100.40
    netmask 255.255.255.0
    gateway 192.168.100.1
    dns-nameservers 8.8.8.8 8.8.4.4
EOF

# Bring up the interface
ip link set eth0 up
ifup eth0

# Verify
ip addr show eth0
ping -c 3 8.8.8.8
```

### Solution 2: Use DHCP (Simpler)

```bash
# Enter container
pct enter 140

# Configure for DHCP
cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Bring up interface
ip link set eth0 up
ifup eth0

# Verify (IP assigned by DHCP)
ip addr show eth0
```

### Solution 3: Automated Script (From Proxmox Host)

```bash
# On Proxmox host (not in container)
ssh root@192.168.100.4

# Set variables
CTID=140
IP="192.168.100.40"
GATEWAY="192.168.100.1"

# Configure network
pct exec $CTID -- bash -c "cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $IP
    netmask 255.255.255.0
    gateway $GATEWAY
    dns-nameservers 8.8.8.8 8.8.4.4
EOF"

# Bring up network
pct exec $CTID -- ip link set eth0 up
pct exec $CTID -- ifup eth0

# Verify
pct exec $CTID -- ip addr show eth0
```

### Network Configuration Files Explained

**Location:** `/etc/network/interfaces`

```ini
# Loopback (always needed)
auto lo                          # Start automatically
iface lo inet loopback           # Loopback interface type

# Ethernet interface
auto eth0                        # Start eth0 automatically on boot
iface eth0 inet static           # Use static IP (or 'dhcp')
    address 192.168.100.40       # IP address
    netmask 255.255.255.0        # Subnet mask (/24)
    gateway 192.168.100.1        # Default gateway
    dns-nameservers 8.8.8.8 8.8.4.4  # DNS servers
```

**Alternative: DHCP**

```ini
auto eth0
iface eth0 inet dhcp             # Get IP from DHCP server
```

---

## SSH Access Setup

### Why SSH Doesn't Work Out-of-the-Box

LXC templates are **minimal** and typically **don't include**:
- ❌ SSH server (openssh-server)
- ❌ Python (needed for Ansible)
- ❌ Many utilities

You need to install these manually.

### Step-by-Step SSH Setup

#### Step 1: Enter Container Console

```bash
# Method 1: From Proxmox host
ssh root@192.168.100.4
pct enter 140

# Method 2: From Proxmox Web UI
# Select container → "Console" button
```

#### Step 2: Update Package Cache

```bash
# Inside container
apt update
```

#### Step 3: Install Essential Packages

```bash
# Install SSH server and useful tools
apt install -y \
    openssh-server \
    python3 \
    sudo \
    curl \
    wget \
    vim \
    net-tools \
    iputils-ping \
    locales

# Explanation:
# openssh-server - SSH daemon for remote access
# python3        - Needed for Ansible
# sudo           - Privilege escalation
# curl/wget      - Download tools
# vim            - Text editor
# net-tools      - ifconfig, netstat
# iputils-ping   - Ping utility
# locales        - Fix locale warnings
```

#### Step 4: Configure Locale (Fix Warnings)

```bash
# Generate US English locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# Verify
locale
```

#### Step 5: Enable and Start SSH

```bash
# Enable SSH to start on boot
systemctl enable ssh

# Start SSH now
systemctl start ssh

# Check status
systemctl status ssh

# Should show: "active (running)"
```

#### Step 6: Configure SSH Keys

**Option A: Add SSH Key Manually**

```bash
# Create .ssh directory
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Add your public key
cat > /root/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... your-public-key-here
EOF

# Set permissions
chmod 600 /root/.ssh/authorized_keys

# Verify
cat /root/.ssh/authorized_keys
```

**Option B: Copy from Proxmox Host**

```bash
# Exit container first
exit

# On Proxmox host, copy key to container
cat ~/.ssh/vm-deb13.pub | pct exec 140 -- bash -c 'mkdir -p /root/.ssh && cat > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys'

# Verify
pct exec 140 -- cat /root/.ssh/authorized_keys
```

**Option C: Copy from Your Local Machine**

```bash
# From your local machine (macOS/Linux)
ssh-copy-id -i ~/.ssh/vm-deb13 root@192.168.100.40

# Or manually:
cat ~/.ssh/vm-deb13.pub | ssh root@192.168.100.40 'cat >> /root/.ssh/authorized_keys'
```

#### Step 7: Test SSH Connection

```bash
# From your local machine
ssh -i ~/.ssh/vm-deb13 root@192.168.100.40

# Should connect without password!
```

#### Step 8: Set Hostname (Optional but Recommended)

```bash
# Enter container
pct enter 140

# Set hostname
echo "grafana-stack" > /etc/hostname
hostname grafana-stack

# Update /etc/hosts
cat > /etc/hosts << 'EOF'
127.0.0.1       localhost
192.168.100.40  grafana-stack

::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# Verify
hostname
```

---

## Storage Management

### View Disk Usage

```bash
# Disk space
df -h

# Directory sizes
du -sh /var/* | sort -h
```

### Resize Container Disk

```bash
# On Proxmox host
pct resize 140 rootfs +20G

# Verify (inside container)
df -h
```

### Add Additional Mount Points

```bash
# On Proxmox host
pct set 140 -mp0 /mnt/data,mp=/data,size=100G

# Inside container
ls -la /data
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
pct start 140
journalctl -xe

# Check configuration
pct config 140

# Check for errors
pct status 140
```

### Network Not Working

```bash
# Inside container
ip addr show          # Check if interface has IP
ip route show         # Check routing table
ping 192.168.100.1    # Test gateway
ping 8.8.8.8          # Test internet
ping google.com       # Test DNS

# If ping fails:
cat /etc/resolv.conf  # Check DNS config
```

### SSH Connection Refused

```bash
# Inside container
systemctl status ssh           # Is SSH running?
ss -tlnp | grep :22            # Is port 22 listening?
cat /root/.ssh/authorized_keys # Is key present?

# Check firewall (if enabled)
ufw status
```

### Permission Denied Errors

```bash
# Check file ownership
ls -la /path/to/file

# Fix ownership
chown user:group /path/to/file

# Fix permissions
chmod 644 /path/to/file    # Files
chmod 755 /path/to/dir     # Directories
chmod 600 ~/.ssh/*         # SSH keys
```

### Container Performance Issues

```bash
# Check resource limits
pct config 140 | grep -E 'cores|memory|swap'

# Inside container - check actual usage
top
free -h
df -h

# On Proxmox host - view all container resource usage
pct status 140 --verbose
```

---

## Common LXC Commands Reference

### Container Lifecycle

```bash
pct create <vmid> <template>    # Create container
pct start <vmid>                # Start container
pct stop <vmid>                 # Stop container
pct shutdown <vmid>             # Graceful shutdown
pct reboot <vmid>               # Reboot container
pct destroy <vmid>              # Delete container (careful!)
pct status <vmid>               # Show status
pct list                        # List all containers
```

### Container Management

```bash
pct enter <vmid>                # Enter container console
pct exec <vmid> -- <command>    # Execute command in container
pct console <vmid>              # Attach to container console (Ctrl+O to exit)
pct config <vmid>               # Show configuration
pct set <vmid> -<option> <value> # Modify configuration
```

### Snapshots and Backups

```bash
pct snapshot <vmid> <name>      # Create snapshot
pct listsnapshot <vmid>         # List snapshots
pct rollback <vmid> <name>      # Restore snapshot
pct delsnapshot <vmid> <name>   # Delete snapshot
```

### File Operations

```bash
pct push <vmid> <src> <dst>     # Copy file TO container
pct pull <vmid> <src> <dst>     # Copy file FROM container
```

---

## Complete Setup Checklist

Use this checklist when creating a new LXC container:

- [ ] **Download Template**
  ```bash
  pveam download local debian-13-standard_13.1-2_amd64.tar.zst
  ```

- [ ] **Create Container** (UI or CLI)
  - [ ] Set unique VMID
  - [ ] Choose hostname
  - [ ] ✅ Enable "Unprivileged"
  - [ ] Configure CPU/RAM
  - [ ] Set static IP or DHCP
  - [ ] Add SSH key (if available)

- [ ] **Start Container**
  ```bash
  pct start 140
  ```

- [ ] **Configure Network** (if needed)
  ```bash
  pct enter 140
  # Edit /etc/network/interfaces
  # ifup eth0
  ```

- [ ] **Install Essential Packages**
  ```bash
  apt update
  apt install -y openssh-server python3 sudo curl wget vim locales
  ```

- [ ] **Configure Locale**
  ```bash
  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
  locale-gen
  ```

- [ ] **Enable SSH**
  ```bash
  systemctl enable --now ssh
  ```

- [ ] **Add SSH Keys**
  ```bash
  mkdir -p /root/.ssh && chmod 700 /root/.ssh
  # Add public key to /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
  ```

- [ ] **Set Hostname**
  ```bash
  echo "hostname" > /etc/hostname
  hostname hostname
  # Update /etc/hosts
  ```

- [ ] **Test Connectivity**
  ```bash
  ping -c 3 8.8.8.8
  ssh root@<container-ip>
  ```

- [ ] **Create Snapshot** (recommended before major changes)
  ```bash
  pct snapshot 140 initial-setup
  ```

---

## Best Practices

### Security

1. ✅ **Always use unprivileged containers** (unless specific requirement)
2. ✅ **Use SSH keys** instead of passwords
3. ✅ **Keep containers updated**: `apt update && apt upgrade`
4. ✅ **Minimize installed packages**: Only install what you need
5. ✅ **Use firewall** (ufw) if exposing services to internet
6. ✅ **Regular snapshots** before major changes

### Resource Management

1. 📊 **Right-size resources**: Don't over-allocate CPU/RAM
2. 📊 **Monitor usage**: Use `top`, `htop`, `df -h`
3. 📊 **Set appropriate swap**: 25-50% of RAM is typical
4. 📊 **Plan for growth**: Leave headroom for expansion

### Maintenance

1. 🔧 **Regular updates**: Weekly or monthly
2. 🔧 **Snapshot before changes**: Always create snapshot before major changes
3. 🔧 **Document changes**: Keep notes on custom configurations
4. 🔧 **Test backups**: Verify snapshots can be restored

### Organization

1. 📁 **Consistent VMID scheme**: 100-199 for dev, 200-299 for prod, etc.
2. 📁 **Clear naming**: Use descriptive hostnames
3. 📁 **Use tags**: Label containers by purpose (monitoring, web, db)
4. 📁 **Resource pools**: Group related containers

---

## Quick Reference: Unprivileged vs Privileged

```
┌────────────────────────────────────────────────────────────┐
│ WHEN TO USE UNPRIVILEGED (Default - Recommended)          │
├────────────────────────────────────────────────────────────┤
│ ✅ Web servers (nginx, Apache, Caddy)                     │
│ ✅ Application servers (Node.js, Python, Go)              │
│ ✅ Databases (PostgreSQL, MySQL, MongoDB)                 │
│ ✅ Monitoring (Grafana, Prometheus, Loki)                 │
│ ✅ CI/CD runners                                           │
│ ✅ Most production workloads                              │
│                                                            │
│ Security: ⭐⭐⭐⭐⭐ Excellent                               │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ WHEN TO USE PRIVILEGED (Only When Required)               │
├────────────────────────────────────────────────────────────┤
│ ⚠️  Docker host (needs nesting + privileges)              │
│ ⚠️  Nested LXC containers                                 │
│ ⚠️  NFS server/client with strict UID requirements        │
│ ⚠️  Applications requiring kernel modules                 │
│ ⚠️  Direct hardware access needed                         │
│                                                            │
│ Security: ⭐⭐ Poor - Use with extreme caution             │
└────────────────────────────────────────────────────────────┘
```

---

## Summary

**LXC Containers are:**
- ✅ Fast and lightweight
- ✅ Share host kernel (efficient)
- ✅ Perfect for services and applications
- ✅ Unprivileged by default (secure)

**Key Steps:**
1. Download template
2. Create container (unprivileged)
3. Configure network
4. Install SSH + essentials
5. Add SSH keys
6. Test connectivity
7. Deploy your application!

**Remember:**
- Unprivileged = Secure (always use unless you can't)
- Network config is manual (unlike VMs with cloud-init)
- Minimal templates require package installation
- Snapshots are your friend!

---

## Additional Resources

- **Proxmox LXC Documentation**: https://pve.proxmox.com/wiki/Linux_Container
- **LXC Official Docs**: https://linuxcontainers.org/lxc/documentation/
- **Debian Network Configuration**: https://wiki.debian.org/NetworkConfiguration
- **SSH Security Best Practices**: https://www.ssh.com/academy/ssh/authorized-keys-file

---

**Created:** 2025-01-22
**For:** Proxmox VE LXC Container Manual Setup
**Author:** Claude Code

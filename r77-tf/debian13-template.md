# Proxmox VM Template

## Installing Debian 13

- VMID: 999
- VM Hardware: vCPU: 2 cores, RAM: 2GB, Storage: 12GB (local-zfs)
- Enable `Qemu`
- Hostname: debian
- Root password: `itisr00ter`
- New user: `a1/a1isd3u5er`
- Partition disks:
  - Guided - use entire disk
  - All files in one partition

## Base setting up

- Login as `root`
- Set up `sudo`
  - Install: `apt install sudo`
  - Add `a1` to `sudo` group: `usermod -aG sudo a1`
  - Visudo: `visudo`, then add this line for automation task:
    - `a1 ALL=(ALL) NOPASSWD:ALL`

- Install or ensure Qemu guest agent is installed.
- Install `cloud-init`: Allow automatic hostname, SSH key, user config when cloning.
  - `sudo apt install cloud-init`
  - Disable default cloud-init network config: `sudo touch /etc/cloud/cloud-init.disabled`

- Clean system:
  - Remove SSH keys: `sudo rm -f /etc/ssh/ssh_host_*`
  - Clean cloud-init data: `sudo cloud-init clean --logs`
  - Clean apt cache + temp logs

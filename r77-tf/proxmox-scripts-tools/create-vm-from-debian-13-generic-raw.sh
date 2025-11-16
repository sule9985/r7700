# Set a VMID
VMID=9999
# Create a new VM
qm create $VMID \
    --name debian13-cloud-template \
    --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 \
    --boot c \
    --ostype 126 \
    --serial0 socket --vga serial0

# Import the disk
qm importdisk $VMID /var/lib/vz/images/debian-13-generic-amd64.raw local-zfs

# Attach the disk
qm set $VMID --scsi0 local-zfs:vm-9999-disk-0

# Add cloud-init drive
qm set $VMID --ide2 local-zfs:cloudinit

qm set $VMID --agent enabled=1
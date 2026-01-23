#!/bin/bash
# Quick Storage Cleanup Script
# WARNING: Review what will be deleted before running!
# Run on Proxmox host: ssh root@nuc.local < cleanup_storage.sh

set -e

echo "=== Storage Cleanup Script ==="
echo "WARNING: This will delete files. Review carefully!"
echo ""

# Check current status
echo "Current thin pool usage:"
lvs -o lv_name,data_percent | grep data
echo ""

# Function to confirm before deletion
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
    fi
    return 0
}

# 1. Clean old container templates
echo "=== Step 1: Clean Old Container Templates ==="
echo "Old templates found:"
pvesm list local | grep vztmpl | grep -v "debian-12-standard_12.7-1\|ubuntu-24.04-standard_24.04-2\|alpine-3.22"

if confirm "Delete old container templates?"; then
    echo "Deleting old templates..."
    pvesm list local | grep vztmpl | grep -v "debian-12-standard_12.7-1\|ubuntu-24.04-standard_24.04-2\|alpine-3.22" | \
    while read volid format type size vmid; do
        if [ -n "$volid" ]; then
            echo "  Deleting: $volid"
            pvesm free "$volid" || echo "    Failed to delete $volid"
        fi
    done
fi
echo ""

# 2. Clean old backups
echo "=== Step 2: Clean Old Backups ==="
echo "Backups found:"
pvesm list local | grep backup

if confirm "Delete old backups? (Make sure you have external backups!)"; then
    pvesm list local | grep backup | \
    while read volid format type size vmid; do
        if [ -n "$volid" ]; then
            echo "  Deleting: $volid"
            pvesm free "$volid" || echo "    Failed to delete $volid"
        fi
    done
fi
echo ""

# 3. Trim unused space in VMs
echo "=== Step 3: Trim Unused Space in VMs ==="
if confirm "Run fstrim on all VMs to free unused blocks?"; then
    for vmid in 100 103 106; do
        echo "  Trimming VM $vmid..."
        qm guest cmd "$vmid" fstrim 2>/dev/null || echo "    VM $vmid: fstrim not available or VM not running"
    done
fi
echo ""

# 4. Check VM 106 disk-1
echo "=== Step 4: Review VM 106 Disk Usage ==="
echo "VM 106 disk status:"
lvs -o lv_name,data_percent,size | grep vm-106

echo ""
echo "VM 106 has two disks. Disk-1 (vm-106-disk-1) is only 3.68% used."
echo "If this disk is not needed, you can remove it with:"
echo "  qm disk unlink 106 --idlist scsi1"
echo ""
echo "⚠️  MANUAL STEP REQUIRED: Review VM 106 config before removing disk!"
echo ""

# Final status
echo "=== Final Status ==="
echo "Thin pool usage:"
lvs -o lv_name,data_percent | grep data
echo ""
echo "Volume group free space:"
vgs -o vg_name,vg_free
echo ""
echo "Done! Review the output above."

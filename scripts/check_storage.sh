#!/bin/bash
# Storage Health Check Script for Proxmox
# Run on Proxmox host: ssh root@nuc.local < check_storage.sh

echo "=== Proxmox Storage Health Check ==="
echo ""

echo "1. Thin Pool Status:"
echo "-------------------"
lvs -o lv_name,data_percent,metadata_percent,size,pool_lv | grep -E 'data|LV'
echo ""

echo "2. Volume Group Free Space:"
echo "---------------------------"
vgs -o vg_name,vg_size,vg_free
echo ""

echo "3. VM Disk Usage in Thin Pool:"
echo "-------------------------------"
lvs -o lv_name,data_percent,size,pool_lv | grep -E 'vm-|LV' | grep data
echo ""

echo "4. Storage Usage by Storage Type:"
echo "---------------------------------"
pvesm status | grep -E 'local|local-lvm'
echo ""

echo "5. Container Templates (can be cleaned):"
echo "----------------------------------------"
pvesm list local | grep vztmpl
echo ""

echo "6. Old Backups (can be cleaned):"
echo "--------------------------------"
pvesm list local | grep backup
echo ""

echo "7. Storage Warnings:"
echo "-------------------"
DATA_PERCENT=$(lvs --noheadings -o data_percent pve/data 2>/dev/null | tr -d ' ' | cut -d. -f1)
if [ -n "$DATA_PERCENT" ]; then
    if [ "$DATA_PERCENT" -ge 90 ]; then
        echo "⚠️  CRITICAL: Thin pool at ${DATA_PERCENT}% - immediate action required!"
    elif [ "$DATA_PERCENT" -ge 80 ]; then
        echo "⚠️  WARNING: Thin pool at ${DATA_PERCENT}% - should free up space"
    else
        echo "✓ Thin pool at ${DATA_PERCENT}% - healthy"
    fi
fi

VG_FREE=$(vgs --noheadings -o vg_free pve 2>/dev/null | tr -d ' ')
if [ "$VG_FREE" = "0" ] || [ -z "$VG_FREE" ]; then
    echo "⚠️  WARNING: Volume group has no free space - cannot expand thin pool"
else
    echo "✓ Volume group has free space: $VG_FREE"
fi

echo ""
echo "=== Recommendations ==="
if [ "$DATA_PERCENT" -ge 80 ]; then
    echo "1. Check VM 106 disk-1 (only 3.68% used) - consider removing if not needed"
    echo "2. Clean up old container templates"
    echo "3. Remove old backups or move to external storage"
    echo "4. Run 'qm guest cmd <VMID> fstrim' on all VMs to free unused space"
fi

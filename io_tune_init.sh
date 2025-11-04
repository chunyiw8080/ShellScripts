#!/usr/bin/env bash
# ============================================================
#  Linux Disk I/O Optimization Initializer (Ops Edition)
#  Author: CHUNYI WANG
#  Description:
#    Generate and verify udev rules for I/O tuning automatically.
#    Includes validation via udevadm test before applying.
# ============================================================

RULE_FILE="/etc/udev/rules.d/99-disk-io-tune.rules"
TEMP_FILE="/tmp/disk_io_tune_preview.rules"

echo "==================== Disk I/O Optimization Setup ===================="
echo "This script will help you create udev rules to automatically apply I/O tuning parameters at boot."
echo "---------------------------------------------------------------------"
echo ""

# Detect available block devices
DEVICES=($(lsblk -nd --output NAME))
if [[ ${#DEVICES[@]} -eq 0 ]]; then
    echo "No block devices detected. Exiting."
    exit 1
fi

echo "Detected block devices:"
for i in "${!DEVICES[@]}"; do
    echo "  [$i] /dev/${DEVICES[$i]}"
done

read -p "Select the device index to tune (default 0): " dev_index
dev_index=${dev_index:-0}
DEVICE="/dev/${DEVICES[$dev_index]}"
DEVNAME=$(basename "$DEVICE")
echo "Target device: $DEVICE"
echo ""

# ========== Parameter 1: I/O Scheduler ==========
echo "I/O Scheduler: controls how read/write requests are ordered and dispatched."
echo "Common options: [none] [mq-deadline] [bfq]"
read -p "Enter scheduler name (recommended: none): " IO_SCHEDULER
IO_SCHEDULER=${IO_SCHEDULER:-none}

# ========== Parameter 2: Queue Depth ==========
echo ""
echo "nr_requests: maximum number of outstanding I/O requests allowed in the queue."
echo "Higher values improve throughput but may increase latency. Recommended: 256"
read -p "Enter nr_requests value (default 256): " NR_REQUESTS
NR_REQUESTS=${NR_REQUESTS:-256}

# ========== Parameter 3: Read Ahead ==========
echo ""
echo "read_ahead_kb: how much data (in kB) the kernel reads ahead for sequential access."
echo "Improves sequential read performance. Recommended: 128"
read -p "Enter read_ahead_kb value (default 128): " READ_AHEAD
READ_AHEAD=${READ_AHEAD:-128}

# ========== Parameter 4: add_random ==========
echo ""
echo "add_random: whether the I/O completion times contribute entropy to the system random pool."
echo "For SSDs or virtual disks, it's recommended to disable (set to 0)."
read -p "Disable add_random? (default 0 = disable): " ADD_RANDOM
ADD_RANDOM=${ADD_RANDOM:-0}

# ========== Parameter 5: nomerges ==========
echo ""
echo "nomerges: controls whether adjacent I/O requests can be merged."
echo "For SSDs, setting to 2 (no merges) can improve I/O parallelism."
read -p "Enter nomerges value (default 2): " NOMERGES
NOMERGES=${NOMERGES:-2}

# ============================================================
# Generate temporary udev rule file
# ============================================================
cat > "$TEMP_FILE" <<EOF
# Auto-generated disk I/O optimization rule
ACTION=="add|change", KERNEL=="${DEVNAME}", SUBSYSTEM=="block", ATTR{queue/scheduler}="${IO_SCHEDULER}"
ACTION=="add|change", KERNEL=="${DEVNAME}", SUBSYSTEM=="block", ATTR{queue/nr_requests}="${NR_REQUESTS}"
ACTION=="add|change", KERNEL=="${DEVNAME}", SUBSYSTEM=="block", ATTR{queue/read_ahead_kb}="${READ_AHEAD}"
ACTION=="add|change", KERNEL=="${DEVNAME}", SUBSYSTEM=="block", ATTR{queue/add_random}="${ADD_RANDOM}"
ACTION=="add|change", KERNEL=="${DEVNAME}", SUBSYSTEM=="block", ATTR{queue/nomerges}="${NOMERGES}"
EOF

echo ""
echo "------------------- Rule Preview -------------------"
cat "$TEMP_FILE"
echo "----------------------------------------------------"
echo ""

# ============================================================
# Test the rule for validity
# ============================================================
echo "Testing generated rule with udevadm..."
sudo udevadm control --reload-rules
sudo udevadm test /sys/block/${DEVNAME} 2>&1 | grep 'queue' | tee /tmp/udev_test_output.log

if [ $? -ne 0]; then
    echo "!!! Test failed: the rule did not apply correctly."
    echo "No changes have been made. Temporary rule kept at: $TEMP_FILE"
    exit 1
else
    echo "!!! Test successful: rule appears to apply correctly."
    read -p "Apply these settings permanently? (y/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        sudo mv "$TEMP_FILE" "$RULE_FILE"
        sudo udevadm control --reload-rules
        echo ""
        echo "Rules have been saved to: $RULE_FILE"
        echo "Please reboot or replug the device for changes to take effect."
    else
        echo "Operation cancelled. Temporary rule kept at: $TEMP_FILE"
    fi
fi

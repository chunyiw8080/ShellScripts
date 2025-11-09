#!/bin/bash

echo "=== IO Health Check; Date: $(date) ==="

echo "1. Equipment utilization rate:"
iostat -x 1 1 | grep -E "(Device|sd|nvme)" | column -t

echo -e "\n2. TOP 10 IO Processes:"
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -10

echo -e "\n3. Disk Space:"
df -h | grep -E "(Filesystem|/dev/sd)"

echo "===================IO Health Check Complete==================="

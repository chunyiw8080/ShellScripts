#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: host_alive.sh
# Description: This script detects the survival status of the host
# Author:      CW
# Date:        2022-10-13
# Version:     1.1
# Usage:       ./host_alive <host_list.txt>
# -----------------------------------------------------------------------------

if [ $# -ne 1 ]; then
    echo "Usage: $0 ip_list.txt"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "$1 not found"
    exit 1
fi

> result.log

for ip in $(cat $1); do
    if ! ping -c 2 -W 2 "$ip" &> /dev/null; then
        echo "$ip" >> result.log
    fi
done

echo "Ping test completed. Unresponsive IPs are logged in result.log."
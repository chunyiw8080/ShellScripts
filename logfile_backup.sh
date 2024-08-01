#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: logfile_backup.sh
# Description: This script packages the files in the specified directory into a compressed file
# Author:      CW
# Date:        2022-10-11
# Version:     1.0
# -----------------------------------------------------------------------------
dir=$1
target=$2

if [ -z "$dir" ] || [ -z "$target" ];then
    echo "Invalid log path or target directory path."
    echo "Usage: ./logfile_backup.sh target_dir logfile_dir."
    exit 1
fi

if [ ! -d "$dir" ]; then
    mkdir "$dir"
fi

if [ ! -d "$target" ]; then
    echo "Log file directory does not exist: $target"
    exit 1
fi

archive="$dir/logs_$(date +%F).tar.gz"
if tar -zcf "$archive" "$target" &> /dev/null; then
    echo "Logs have been successfully backed up to $archive"
    exit 0
else
    echo "Failed to create backup archive."
    exit 1
fi
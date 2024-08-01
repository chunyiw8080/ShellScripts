#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: create_user.sh
# Description: This script creates user and set password for it.
# Author:      CW
# Date:        2022-10-11
# Version:     1.1
# Usage:       ./create_user.sh <username> <password>
# -----------------------------------------------------------------------------

username=$1
password=$2

if useradd "$username" &> /dev/null; then
    echo "User $username has been added to the system."
else
    echo "Unable to create user: $username, username is invalid or username already exists"
    exit 1
fi

if echo "$username:$password" | chpasswd; then
    echo "Password has been set for user: $username"
    exit 0
else
    echo "Failed to set password for user: $username."
    userdel -r $username &> /dev/null
    echo "User: $username has been removed."
    exit 1
fi
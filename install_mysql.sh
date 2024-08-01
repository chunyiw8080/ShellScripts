#!/bin/bash
# -----------------------------------------------------------------------------
# Script Name: install_mysql.sh
# Description: This script installs MySQL from source on a specified location.
# Author:      CW
# Date:        2023-01-22
# Version:     1.0
# -----------------------------------------------------------------------------

url=$1
location=$2
installPath=$3

if [ -z "$url" ] || [ -z "$location" ] || [ -z "$installPath" ]; then
    echo "Invalid source URL, download location, or installation path."
    echo "Usage: $0 <source_url> <download_location> <installation_path>"
    exit 1
fi

echo "Installing dependencies..."
if ! yum install -y centos-release-scl &> /dev/null || ! yum install -y devtoolset-10-gcc devtoolset-10-gcc-c++ devtoolset-10-binutils git cmake3 ncurses-devel openssl-devel bison wget &> /dev/null; then
    echo "Failed to install dependencies."
    exit 1
fi

source /opt/rh/devtoolset-10/enable

version=$(basename "$url" .tar.gz)
echo "MySQL version to install: $version"

echo "Downloading $version..."
if ! wget -P "$location" "$url" &> /dev/null; then
    echo "Invalid source URL or failed to download."
    exit 1
fi

echo "Unzipping..."
if ! tar -xzvf "$location/$version.tar.gz" -C "$location" &> /dev/null; then
    echo "Failed to unzip the file."
    exit 1
fi

echo "Compiling $version..."
cd "$location/$version" && mkdir build && cd build
if ! cmake3 .. -DDOWNLOAD_BOOST=1 -DWITH_BOOST=../boost -DCMAKE_INSTALL_PREFIX="$installPath" &> /dev/null || ! make &> /dev/null || ! make install &> /dev/null; then
    echo "Failed to compile and install $version."
    exit 1
fi

if ! id mysql &> /dev/null; then
    echo "Creating MySQL user and group..."
    groupadd mysql && useradd -r -g mysql -s /bin/nologin mysql
else
    echo "MySQL user already exists."
fi

echo "Initializing MySQL data directory..."
cd "$installPath" && mkdir -p mysql-files && chmod 750 mysql-files && chown -R mysql:mysql .
if ! bin/mysqld --initialize --user=mysql --basedir="$installPath" --datadir="$installPath/data" &> /dev/null; then
    echo "Failed to initialize MySQL data directory."
    exit 1
fi

echo "Configuring MySQL systemd module..."
cp "$installPath/support-files/mysql.server" /etc/init.d/mysql
systemctl daemon-reload
systemctl enable mysql
systemctl start mysql

echo "Configuring environment variables..."
if ! grep -q "$installPath/bin" /etc/profile; then
    echo "export PATH=$installPath/bin:\$PATH" >> /etc/profile
    source /etc/profile
fi

echo "MySQL installation completed successfully."

exit 0








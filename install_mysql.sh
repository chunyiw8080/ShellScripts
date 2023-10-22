#!/bin/bash

downloadLoc=""
downloadLink=""
CONF=""
archieveFile=""

function download(){ 
    archieveFile=$(basename $downloadLink)
    if [ ! -e ${downloadLoc}/${archieveFile} ]; then
        mkdir -p $downloadLoc
        wget -P ${downloadLoc} $downloadLink || {
            if [[ $? -ne 0 ]]; then
                hint "RED" "FATAL: Download failed."
                exit 1
            fi
        }
    fi
}
function install(){
    cd $downloadLoc
    tar -xf $archieveFile
    if [[ $? -eq 0 ]]; then
        local filename=$(echo $archieveFile | sed 's/.tar.gz//')
        local version=$(echo $filename | sed 's/-/ /g' | awk '{print $2}')
        mv $filename mysql-$version 
        ln -s mysql-$version mysql
    else
        hint "RED" "FATAL: Failed to extract file"
        exit 1
    fi
}
function setEnv(){
    echo 'export PATH=$PATH:'"$downloadLoc"'/mysql/bin' >> /etc/profile
    source /etc/profile
}
function createUser(){
    useradd -s /sbin/nologin -M mysql
    chown -R mysql.mysql /$downloadLoc/mysql*
}
function defaultConf(){
    mkdir $downloadLoc/mysql_data
    cat > /etc/my.cnf << EOF
[mysqld]
port=3306
user=mysql
basedir=$downloadLoc/mysql
datadir=$downloadLoc/mysql_data
socket=/tmp/mysql.sock

[mysql]
socket=/tmp/mysql.sock
EOF
}
function copyConf(){
    rm -f /etc/my.cnf 
    cp $CONF /etc/my.cnf
}
function initialization(){
    cp /opt/mysql/support-files/mysql.server /etc/init.d/mysqld
    systemctl daemon-reload
    mysqld --initialize-insecure --user=mysql --basedir=$downloadLoc/mysql --datadir=$downloadLoc/mysql_data
    systemctl start mysqld
}
function hint(){
    local color=$1
    local words=$2
    case $color in
    GREEN)
        echo -e "\033[32m ${words} \033[0m"
        ;;
    RED)
        echo -e "\033[31m ${words} \033[0m"
        ;;
    YELLOW)
        echo -e "\033[33m ${words} \033[0m"
        ;;
    esac
}
function main {
    while getopts "l:p:c:h" opt; do
        case $opt in
        l)
            downloadLink="$OPTARG"
            ;;
        p)
            downloadLoc="$OPTARG"
            ;;
        c)
            status=1
            CONF="$OPTARG"
            ;;
        h)
            echo -e "Usage: ./install_mysql \n-l: The Url link where mysql can be downloaded;\n-p: The path to save the downloaded file;\n-c: Optional, path to your my.cnf file."
            exit 0
            ;;
        \?)
            exit 1
            ;;
        esac
    done

    if [ -z "$downloadLink" ] || [ -z "$downloadLoc" ]; then
        hint "RED" "FATAL: Invalid parameters"
        exit 1
    else
        download
        install
        setEnv
        createUser
        if [ -z "$status" ]; then
            defaultConf
        else
            copyConf
        fi
        initialization
    fi
}

main $1 $2 $3 $4 $5 $6 || {
    if [[ $? -ne 0 ]]; then
        hint "RED" "FATAL: Something Wrong, exit ..."
        exit 1
    fi
}
hint "GREEN" "ALL DONE, use <mysqladmin password -S /tmp/mysql.sock ******> to set password for root user"




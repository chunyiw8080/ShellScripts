#!/bin/bash

# *************************************************************************** #
# * 
# * @file:deploy_wordpress
# * @author:CHUNYI WANG 
# * @date:2023-04-29 18:27 
# * @version 1.0  
# * @description: A shell script used to deploy LNMP (Nginx php-fpm mariadb and wordpress)
# * 
# ************************************************************************** # 
name=''
install_path=''

function service_status(){
    local service=$1
    local result=$(systemctl status ${service} | grep Active | awk '{print $2}') > /dev/null 2>&1
    if [ ${result} == 'active' ]; then
        return 0
    else
        return 1
    fi
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

function config_php8(){
    hint "YELLOW" "Configuring the yum source for php8 ..."
    yum install yum-utils -y > /dev/null 2>&1
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm > /dev/null 2>&1
    yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm > /dev/null 2>&1

    yum-config-manager --disable 'remi-php*' > /dev/null 2>&1
    yum-config-manager --enable remi-php80 > /dev/null 2>&1

    hint "GREEN" "DONE"

    hint "YELLOW" "Installing php-mysql extensions ..."
    yum install -y php-mysql php-cli php-common php-devel php-embedded php-gd php-mcrypt php-mbstring php-pdo php-xml php-fpm php-mysqlnd php-opcache php-pecl-memcached php-pecl-redis php-pecl-mongodb php-json php-pecl-apcu php-pecl-apcu-devel > /dev/null 2>&1
    hint "GREEN" "DONE"
}

function install(){
    hint "YELLOW" "Checking and installing the software environment ..."

    local service=(nginx php php-fpm mariadb mariadb-server)
    for (( i=0; i<${#service[@]}; i++ ))
    do
        local result=$(rpm -qa ${service[$i]})
        if [ -n "${result}" ]; then
            yum remove ${service[$i]}* -y > /dev/null 2>&1
        fi
    done

    for (( i=0; i<${#service[@]}; i++ ))
    do
        yum install ${service[$i]} -y > /dev/null 2>&1
    done

    hint "GREEN" "DONE"
}

function create_user(){
    hint "YELLOW" "Create a user to run nginx ..."
    while true
    do
        read -p $'Enter the user name: \n' name
        read -p $'Enter the uid: \n' id

        local result_name=$(cat /etc/passwd | grep -w ${name}) > /dev/null 2>&1
        local result_id=$(cat /etc/passwd | awk 'BEGIN{FS=":"}{print $3}' | grep -w ${id}) > /dev/null 2>&1
        if [ -n "${result_name}" ] || [ -n "${result_id}" ]; then
            hint "RED" "Username or UID already exists!"
        else
            groupadd ${name} -g ${id}
            useradd ${name} -s /sbin/nologin -M -u ${id} -g ${id}
            if [ -n "$(cat /etc/passwd | grep -w ${name})" ] > /dev/null 2>&1; then
                hint "GREEN" "DONE"
                break
            else
                hint "RED" "FATAL: unable to create user ${name}"
            fi
        fi
    done
}

function modify_configuration(){
    sed -i '/^user/c user = www' /etc/php-fpm.d/www.conf > /dev/null 2>&1
    sed -i '/^group/c group = www' /etc/php-fpm.d/www.conf > /dev/null 2>&1
}

function mysql_setup(){
    hint "YELLOW" "Setup mysql database ..."
    if ! service_status "mariadb"; then
        systemctl start mariadb > /dev/null 2>&1
    fi

    read -p $'Set mysql administator password: \n' mysql_password
    mysqladmin password ${mysql_password}
    if [ $? != 0 ]; then
        hint "RED" "FATAL: You have already set the admin password."
        read -p "Do you want to reset the password? y/n" choice
        while true
        do
            if [ ${choice} == 'n' ]; then
                break;
            else
                read -p $'Enter the current mysql admin password: \n' old_password
                read -p $'Enter the new mysql admin password: \n' new_password
                mysqladmin -p"${old_password}" password "${new_password}"
                if [ $? != 0 ]; then
                    hint "RED" "FATAL: Incorrect Password"
                else
                    hint "GREEN" "DONE"
                    mysql_password="${new_password}"
                fi
            fi
        done
    else
        hint "GREEN" "DONE"
    fi

    hint "YELLOW" "Create database for wordpress ..."
    while true
    do
        read -p $'Enter the databases name: \n' db_name
        local result=$(mysql -uroot -p"${mysql_password}" -e "show databases;" | grep -w ${db_name})
        if [ -z "${result}" ]; then
            mysql -uroot -p"${mysql_password}" -e "create database ${db_name};"
            hint "GREEN" "DONE"
            break
        else
            hint "RED" "FATAL: Database already exists"
        fi
    done
}

function install_wordpress(){
    hint "YELLOW" "Download and install wordpress ... "
    while true
    do
        read -p $'Enter the installation path: \n' install_path
        ls ${install_path} > /dev/null 2>&1
        if [ -f "${install_path}" ]; then
            hint "RED" "FATAL: Invalid directory"
        else
            mkdir -p "${install_path}"
            break
        fi
    done

    hint "YELLOW" "Downloading wordpress ..."
    cd "${install_path}"; wget https://cn.wordpress.org/latest-zh_CN.zip > /dev/null 2>&1

    hint "YELLOW" "Unzipping wordpress ..."
    unzip latest-zh_CN.zip > /dev/null 2>&1

    chown -R ${name}.${name} ${install_path} > /dev/null 2>&1

    hint "GREEN" "DONE"
}

function make_nginx_config(){
    hint "YELLOW" "Making nginx configuration ..."

    local net_card=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
    local ip_addr=$(ifconfig ${net_card} | awk 'NR==2{print $2}')
    local config="/etc/nginx/conf.d/wordpress.conf"

    echo "server{
    listen 80;
    server_name ${ip_addr};
    root "${install_path}/wordpress";
    index index.php index.html;
    location ~ \.php$ {
        root "${install_path}/wordpress";
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}" > ${config}

    hint "GREEN" "DONE"
}

function start_services(){
    hint "YELLOW" "Starting services ..."
    local services=(mariadb php-fpm nginx)
    for service in ${services[@]}
    do
        systemctl enable ${service} > /dev/null 2>&1
        if ! service_status "${service}"; then
            systemctl start "${service}"
        else
            systemctl restart "${service}"
        fi
    done

    hint "GREEN" "DONE"
}

function check_selinux(){
    hint "YELLOW" "Checking SELINUX status ... "
    local status=$(getenforce)
    if [ ${status} != 'Disabled' ]; then
        sed -i 's/SELINUX=\(Permissive\|Enforcing\)/SELINUX=disabled/g' /etc/selinux/config
        hint "RED" "SELINUX has been disabled, reboot for this change to take effect"
        hint "GREEN" "DONE"
        read -p "Reboot now? y/n " choice
            if [ ${choice} == 'y' ]; then
                reboot
            fi
    else
        hint "YELLOW" "SELINUX is disabled"
        hint "GREEN" "DONE"
    fi
}


config_php8
install
create_user
modify_configuration
mysql_setup
install_wordpress
make_nginx_config
start_services
check_selinux

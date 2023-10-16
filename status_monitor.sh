#!/bin/bash

# *************************************************************************** #
# * 
# * @file:status_monitor.sh 
# * @author:CHUNYI WANG 
# * @date:2023-04-30 14:57 
# * @version 1.0  
# * @description: A Shell script used to monitor the status of web services.
# * 
# ************************************************************************** # 

services=(php-fpm nginx)

email="*****"
smtp_server="smtp.qq.com:465"
passwd="*****"
cert="***"

function check_status(){
	local status=$(systemctl status $1 | grep Active | awk '{print $2}')
	if [ $status == 'active' ]; then
		return 0
	else
		return 1
	fi
}

function isSuccess(){
	if [ $1 != 0 ]; then
		echo -e "Service: $2 unavailable" | mail -s "System warning" "${email}"
	fi
}

function main(){
	for key in ${services[@]}
	do
		if  ! check_status "${key}"; then
			echo "${key} shut down at $(date +%F - %T)" >> /home/centos/alert.log
			systemctl start ${key}
			isSuccess $? ${key}
		fi
	done
}

main

exit 0


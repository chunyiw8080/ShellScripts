#!/bin/bash

# *************************************************************************** #
# * 
# * @file:restart_services.sh 
# * @author:CHUNYI WANG 
# * @date:2023-04-29 18:27 
# * @version 1.0  
# * @description: A shell script used to restart some services.
# * 
# ************************************************************************** # 

services_list=(php-fpm nginx) #A list used to store services that need to get started or restarted
declare -A result #A map used to store the result of start or restart operations

email="973321662@qq.com"
smtp_server="smtp.qq.com:465"
passwd="ysdswkyywbosbbdb"
cert="qq.crt"

## This function is used to determine whether the service has successfully started or restarted, and carry out further commands (send notification email and write the log)
function isSuccess(){
	local service=$1
	if [ $2 != 0 ]; then
		result[${service}]=0
		echo -e "Service ${service} restart failed." | mail -s "System warning" "${email}"
		generate_log ${service} "FAILED"
	else
		result[${service}]=1
		generate_log ${service} "SUCCESS"
	fi
}

## This function is used to start or restart services
function restart_service(){
	local service=$1
	status=$(systemctl status "${service}" | grep Active | awk '{print $2}')
	if [ "${status}" != 'active' ]; then
		systemctl start "${service}" > /dev/null 2>&1
		isSuccess "${service}" $? > /dev/null 2>&1
	else
		systemctl restart "${service}" > /dev/null 2>&1
		isSuccess "${service}" $? > /dev/null 2>&1
	fi
}

## Check if all services have successfully restarted, if so, send a notification email to administartor, otherwise the warning will be sent via the isSuccess() function.
function isAllSuccess(){
	local allSuccess=true
	for key in ${!result[@]}
	do
		if [ "${key}" != "1" ]; then
			allSuccess=false
			break
		fi
	done

	if [ ${allSuccess} ]; then
		echo -e "All services has successfully restarted" | mail -s "System notification" "${email}"
	fi
}

## Used to write the log
function generate_log(){
	local logPath="/home/centos/service_restart.log"
	echo "$(date "+%F - %T") $1 restart $2" >> ${logPath}
}

function main(){
	for (( i=0; i<${#services_list[@]}; i++ ))
	do
		restart_service ${services_list[$i]}
	done
}

main
isAllSuccess

exit 0


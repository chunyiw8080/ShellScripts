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

service_list=(nginx php-fpm)

function check_status(){
	for (( i=0; i<${#service_list[@]}; i++ ))
	do
		echo -n "${service_list[$i]}: "
		systemctl status "${service_list[$i]}" | grep 'Active' | awk '{print $2}'
	done
}

check_status

exit 0


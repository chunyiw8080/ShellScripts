#!/bin/bash

EMAIL_CONF=""
LOGFILE=""
CONF=""

function sendEmail(){
    local userEmails=$(cat $EMAIL_CONF | jq -r 'to_entries[] | .value.email')
    local issue=$1
    local title=$2
    local ipAddress=$(curl -s ifconfig.me)
    for email in $userEmails; do
        echo -e "时间: $(date +"%Y-%m-%d %H:%M:%S")\n主机IP: ${ipAddress}\n问题: $issue" | mail -s "$title" "$email"
    done
}
function writeLog(){
    echo -e "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> $LOGFILE
}
function cpuUsage(){
    local cpuIdle=$(top -bn1 | grep Cpu | sed 's/,/ /g'|awk '{print $8}' | cut -d. -f1)
    local cpuUsed=$[100-$cpuIdle]
    local cpuLimit=$(jq '.cpu.cpu_limit' $CONF)
    #echo "cpuLimit: $cpuLimit"
    if [ $cpuUsed -gt $cpuLimit ]; then
        sendEmail "CPU使用率过高 - ${cpuUsed}%" "警报: CPU使用率过高" 
        writeLog "CPU usage too high"
    fi
}
function memUsage(){
    local memAvail=$(free -h | sed -n '2p' | awk '{print $NF}' | sed 's/[^0-9.]//g')
    local memLimit=$(jq '.memory.memory_limit' $CONF)
    #echo "memLimit: $memLimit"
    if (( $(echo "$memAvail < $memLimit" | bc -l) )); then
        sendEmail "可用内存不足 - 剩余可用内存为${memAvail}M" "警报: 可用内存不足"
        writeLog "Insufficient available memory"
    fi
}
function diskSpaceUsage(){
    local jsonArr=$(jq -r '.disk_space.mount_point[]' $CONF)
    IFS=$'\n' read -rd '' -a mountList <<< "$jsonArr"
    local diskUsageLimit=$(jq '.disk_space.disk_usage_limit' $CONF)
    local diskAvailLimit=$(jq '.disk_space.disk_avail_limit' $CONF)
    for mountPoint in ${mountList[@]}; do    
        local diskUsage=$(df -h $mountPoint | sed -n '2p' | awk '{print $(NF-1)}' | sed 's/[^0-9.]//g')
        local diskAvail=$(df -h $mountPoint | sed -n '2p' | awk '{print $(NF-2)}' | sed 's/[^0-9.]//g')
        echo "mount point: $mountPoint; usage size: $diskUsage; avail: $diskAvail"
        if [ "$diskUsage" -gt "$diskUsageLimit" ] || [ "$diskAvail" -lt "$diskAvailLimit" ]; then
            sendEmail "挂载点\"$mountPoint\" 可用磁盘空间不足 - 剩余磁盘空间为${diskUsage}G" "警报: 可用磁盘空间不足"
            writeLog "Mount point: $mountPoint; Insufficient available disk space"
        fi
    done
}
function connectionStatus(){
    local amount=$(jq '.connection_status.amount' $CONF)
    local jsonArr=$(jq -r '.connection_status.status[]' $CONF)
    IFS=$'\n' read -rd '' -a STATUS <<< "$jsonArr"
    for element in ${STATUS[@]}; do
        #echo "element: $element"
        count=$(netstat -ant | grep -c ${element})
        if [ $count -gt $amount ]; then
            sendEmail "链接状态异常：${STATUS}状态链接数过多, 当前数量${count}个" "警报: 异常状态链接数过多"
            writeLog "Connection status exception: too many $STATUS connections"
        fi  
    done
}
function containerStatus(){
    local containerList=$(docker ps -a | awk '{print $1}' | tail -n +2)
    for container in $containerList; do
        local status=$(docker inspect ${container} | jq -r '.[0].State.Status')
        if [ "$status" != "running" ]; then
            sendEmail "容器状态异常：${container}-${status}" "警报: 容器状态异常"
            writeLog "Container shut down: ${container}"
        fi
    done
}
function serviceStatus(){
    local jsonArr=$(jq -r '.services[]' $CONF)
    IFS=$'\n' read -rd '' -a SERVICE_LIST <<< "$jsonArr"
    for service in ${SERVICE_LIST[@]}; do
        #echo "service: $service"
        pgrep -x "$service" > /dev/null
        if [ $? -eq 1 ]; then
            sendEmail "服务状态异常: ${service} 进程关闭" "警报: 服务状态异常"
            writeLog "Service shut down: ${service}"
        fi
    done
}

while getopts "c:e:l:h" opt; do
    case $opt in
    c)
        CONF="$OPTARG"
        ;;
    e)
        EMAIL_CONF="$OPTARG"
        ;;
    l)
        LOGFILE="$OPTARG"
        ;;
    h)
        echo "Usage: ./monitor.sh -c CONFIGURATION_FILE.json -e EMAIL_CONTACT.json -l LOGFILE.log"
        exit 0
        ;;
    \?)
        exit 1
        ;;
    esac
done
if [ -z "$CONF" ] || [ -z "$EMAIL_CONF" ] || [ -z "$LOGFILE" ]; then
    echo "错误: 未提供正确的文件路径"
    echo "Try './monitor -h' for more information"
    exit 1
fi
if [ ! -f "$CONF" ] || [ ! -f "$EMAIL_CONF" ] || [ ! -f "$LOGFILE" ]; then
    echo "错误: 未找到文件"
    exit 1
else
    cpuUsage
    memUsage
    diskSpaceUsage
    connectionStatus
    containerStatus
    serviceStatus
fi
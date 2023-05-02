ava_mem=$(free -h|grep 'Mem'|awk '{print $NF}' | sed 's/[A-Z]*//g')
email="973321662@qq.com"

if test $[ava_mem] -lt 50; then 
	echo -e "The Available memory has dropped to the warning point;\nAvailable Memory: $ava_mem " | mail -s "System Warning" "${email}"
fi

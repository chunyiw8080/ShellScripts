echo -n "Nginx: " 
systemctl status nginx | grep Active | awk '{print $2}'

echo -n "php-fpm: "
systemctl status php-fpm | grep Active | awk '{print $2}'

echo -n "Mariadb: "
systemctl status mariadb | grep Active | awk '{print $2}'

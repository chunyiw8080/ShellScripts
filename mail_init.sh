#!/bin/bash

rm -rf  /root/.certs
find / -type f -name "*mail.rc*" | xargs -i rm -f {}

email=""
smtp_server="smtp.qq.com:465"
passwd=""
cert="qq.crt"
touch /etc/mail.rc

echo "set from=${email}" >> /etc/mail.rc
echo "set smtp=smtps://${smtp_server}" >> /etc/mail.rc
echo "set smtp-auth-user=${email}" >> /etc/mail.rc
echo "set smtp-auth-password=${passwd}" >> /etc/mail.rc
echo "set smtp-auth=login" >> /etc/mail.rc
echo "set ssl-verify=ignore" >> /etc/mail.rc
echo "set nss-config-dir=/root/.certs" >> /etc/mail.rc

mkdir -p /root/.certs
echo -n | openssl s_client -connect "${smtp_server}" | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ~/.certs/"${cert}"
certutil -A -n "GeoTrust SSL CA" -t "C,," -d ~/.certs -i ~/.certs/"${cert}"
certutil -A -n "GeoTrust Global CA" -t "C,," -d ~/.certs -i ~/.certs/"${cert}"
certutil -L -d /root/.certs
cd /root/.certs
certutil -A -n "GeoTrust SSL CA - G3" -t "Pu,Pu,Pu" -d ./ -i "${cert}"

echo -e "The Mailx service has been initialized.\nThis mail is used for testing." | mail -s "Mailx initialization" "${email}"

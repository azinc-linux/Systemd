#!/bin/bash

cat <<EOF > /opt/observelog.sh
#!/bin/bash
WORD=\$1
LOG=\$2
DATE=\`date\`

if grep \$WORD \$LOG &> /dev/null
then
logger "\$DATE: The \$WORD has been detected"
fi
EOF

chmod +x /opt/observelog.sh

cat <<EOF > /etc/sysconfig/observelog
WORD=\"SERVICE\"
LOG=/var/log/observelog.log
EOF

cat <<EOF > /var/log/observelog.log
THIS IS  SERVICE
EOF

cat <<EOF > /etc/systemd/system/observelog.service
[Unit]
Description=My observelog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/observelog
ExecStart=/opt/observelog.sh \$WORD \$LOG
EOF

cat <<EOF > /etc/systemd/system/observelog.timer
[Unit]
Description=Run observelog script every 30 seconds

[Timer]
OnUnitActiveSec=30
Unit=observelog.service

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl start observelog.service
systemctl start observelog.timer

yum install epel-release -y && sudo yum install spawn-fcgi php php-cli mod_fcgid httpd -y
sed -i 's/#SOCKET/SOCKET/g; s/#OPTIONS/OPTIONS/g' /etc/sysconfig/spawn-fcgi

cat <<EOF > /etc/systemd/system/spawn-fcgi.service
[Unit]
Description=Spawn-fcgi startup service
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n \$OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
systemctl start spawn-fcgi

cat <<EOF > /etc/sysconfig/httpd-first
OPTIONS=-f /etc/httpd/conf/first.conf
EOF

cat <<EOF > /etc/sysconfig/httpd-second
OPTIONS=-f /etc/httpd/conf/second.conf
EOF

sed -i 's/EnvironmentFile=\/etc\/sysconfig\/httpd/EnvironmentFile=\/etc\/sysconfig\/httpd-%I/g' /usr/lib/systemd/system/httpd.service
mv /usr/lib/systemd/system/httpd.service /etc/systemd/system/httpd@.service

cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf
echo "PidFile /run/httpd/httpd-second.pid" >> /etc/httpd/conf/second.conf

sed -i 's/Listen 80/Listen 8080/g' /etc/httpd/conf/second.conf

systemctl daemon-reload
systemctl start httpd@first
systemctl start httpd@second

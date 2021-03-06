#!/bin/bash
pip install supervisor
if [[ ! -r /etc/supervisord.conf ]];then
    echo_supervisord_conf > /etc/supervisord.conf    
fi
supervisord

cat >./supervisord.service <<eof
[Unit] 
Description=Supervisor daemon

[Service] 
Type=forking 
ExecStart=/usr/bin/supervisord -c /etc/supervisord.conf 
ExecStop=/usr/bin/supervisorctl shutdown 
ExecReload=/usr/bin/supervisorctl reload 
KillMode=process 
Restart=on-failure 
RestartSec=42s

[Install] 
WantedBy=multi-user.target
eof
mv ./supervisord.service /usr/lib/systemd/system/
systemctl enable supervisord
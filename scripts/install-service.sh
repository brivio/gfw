#!/bin/bash
. $1
service_script=/opt/$service_name.sh
service_file=/usr/lib/systemd/system/$service_name.service
if [[ $2 = 'uninstall' ]];then
    systemctl stop $service_name
    systemctl disable $service_name
    if [[ -f $service_script ]];then
        rm -f $service_script    
    fi
    if [[ -f $service_file ]];then
        rm -f $service_file    
    fi
    echo "卸载成功"
    exit
fi

cat >$service_script <<eof
#!/bin/bash
_start()
{
    if [[ \$(ps aux|grep "$cmd"|grep -v grep|wc -l) != "1" ]];then
        $cmd
    fi
}

_stop(){
    for pid in \$(ps axo pid,cmd |grep "$cmd"|grep -v grep|awk '{printf "%s\n",\$1}')
    do
        kill \$pid
    done
}

if [[ \$1 = 'start' ]];then
    _start
elif [[ \$1 = 'stop' ]];then
    _stop
elif [[ \$1 = 'restart' ]];then
    _start
    _stop
fi
eof
chmod -R 777 $service_script

cat >$service_file <<eof
[Unit]
Description=$service_name daemon
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=5
User=root
WorkingDirectory=/root
ExecStart=$service_script start
ExecReload=$service_script restart
ExecStop=$service_script stop
 
[Install]
WantedBy=multi-user.target
eof

# systemctl enable $service_name
# systemctl restart $service_name
# systemctl status $service_name
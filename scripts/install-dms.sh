#!/bin/bash
web_dir=$1
server_id=$2
service_name=dms
service_script=/opt/$service_name.sh
cmd="php $web_dir/index.php api/task/dms $server_id"

if [[ ! -r $web_dir/index.php ]];then
    echo "网站目录不存在"
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

cat >/usr/lib/systemd/system/$service_name.service <<eof
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

# systemctl start dms
# systemctl status dms
# systemctl enable dms
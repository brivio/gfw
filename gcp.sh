#!/bin/bash
# 使用方法： 
#    bash <(curl -Ls https://raw.githubusercontent.com/brivio/gfw/master/gcp.sh)
# 变量
v2ray_client_id='c5b501d4-3710-49c5-9623-6dfe8837bcf0'
github_script_url='https://raw.githubusercontent.com/brivio/gfw/master'

COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_BLUE="\033[34m"
COLOR_END="\033[0m"
_build_log(){
    printf "${COLOR_RED}$1${COLOR_END}\n"
}

_set_timezone(){
    _build_log "设置时区"
    timedatectl set-timezone Asia/Shanghai
}

_set_ssh(){
    sshd_config_file=/etc/ssh/sshd_config

    if [[ ! -f $sshd_config_file ]];then
        return
    fi
    if [[ $(cat /etc/ssh/sshd_config|grep 'PermitRootLogin no'|wc -l) -eq 0 ]];then
        return
    fi

    _build_log "设置sshd"
    sed -i 's/PermitRootLogin no/PermitRootLogin yes/g' $sshd_config_file
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' $sshd_config_file
    
    read -p "reset root password:" password
    echo "$password"|passwd --stdin root &>/dev/null
    systemctl restart sshd
}

_install_packages(){
    _build_log "安装git、zsh等依赖"
    yum install -y autoconf automake libtool nmap git zsh zip epel-release net-tools wget &>/dev/null
}

_install_oh_my_zsh(){
    _build_log "安装oh-my-zsh"
    sh -c "$(curl -fsSL $github_script_url/scripts/install-my-zsh.sh)"
    if [[ -f ~/.zshrc ]]; then
        sed -i 's/ZSH_THEME\=\"robbyrussell\"/ZSH_THEME\=\"josh\"/g' ~/.zshrc
        sed -i 's/# DISABLE_AUTO_UPDATE\=\"true\"/DISABLE_AUTO_UPDATE\=\"true\"/g' ~/.zshrc
    fi
}

_install_v2ray(){
    _build_log "安装v2ray"
    bash <(curl -L -s https://install.direct/go.sh) &>/dev/null
    cat >/etc/v2ray/config.json <<EOF
{
  "inbounds": [{
    "listen": "127.0.0.1",
    "port": 27635,
    "protocol": "vmess",
    "settings": {
      "clients": [{
        "id": "$v2ray_client_id",
        "level": 1,
        "alterId": 64
      }]
    },
    "streamSettings": {"network": "ws","wsSettings": {"path": "/ray"}}
  }],
  "outbounds": [{"protocol": "freedom","settings": {}}, {"protocol": "blackhole","settings": {},"tag": "blocked"}],
  "routing": {"rules": [{"type": "field","ip": ["geoip:private"],"outboundTag": "blocked"}]}
}
EOF
    systemctl start v2ray
    systemctl enable v2ray
}

_install_nginx(){
    _build_log "安装nginx"
    rpm -ivh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm >/dev/null
    yum install -y nginx >/dev/null
    web_dir=/var/www/html
    mkdir -p $web_dir
    cat >$web_dir/index.html <<EOF
    <!DOCTYPE html><html lang="en"><head><title></title></head><body><h1 style="text-align: center;">welcome</h1></body></html>
EOF
    read -p "site domain:" domain

    mkdir /etc/nginx/ssl
    cat >/etc/nginx/nginx.conf <<EOF
user  nginx;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    keepalive_timeout  65;
    include /etc/nginx/conf.d/*.conf;
	
	server{
		server_name $domain;
		listen            443 ssl;
		autoindex         on;
        
        root html;
		location / {
            root   /var/www/html/;
            index  index.html index.htm index.php;
		}
        location /ray { 
            proxy_redirect off;
            proxy_pass http://127.0.0.1:27635;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;

            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
	}
}
EOF
    # systemctl start nginx
    systemctl enable nginx
    _build_log "设置ssl证书"
    wget https://dl.eff.org/certbot-auto
    mv certbot-auto /usr/local/bin/certbot-auto
    chown root /usr/local/bin/certbot-auto
    chmod 0755 /usr/local/bin/certbot-auto
    /usr/local/bin/certbot-auto --nginx
    # echo "0 0,12 * * * root python -c 'import random; import time; time.sleep(random.random() * 3600)' && /usr/local/bin/certbot-auto renew" | sudo tee -a /etc/crontab > /dev/null
}

_set_selinux(){
    if type setsebool &>/dev/null;then
        _build_log "设置selinux"
        sed -i 's/SELINUX\=enforcing/SELINUX\=disabled/g' /etc/selinux/config
        setsebool -P httpd_can_network_connect 1    
    fi
}

_set_ports(){
    if type firewall-cmd &>/dev/null;then
        _build_log "开放一些端口号"
        for port in 80 443 8989
        do
            firewall-cmd --permanent --zone=public --add-port=$port/tcp >/dev/null
        done
        firewall-cmd --reload
        firewall-cmd --zone=public --list-ports    
    fi
}

_set_timezone
_set_ssh
_install_packages
_install_oh_my_zsh
_install_v2ray
_install_nginx
_set_selinux
_set_ports
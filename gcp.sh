#!/bin/bash
# 变量
v2ray_client_id='c5b501d4-3710-49c5-9623-6dfe8837bcf0'

# 设置时区
timedatectl set-local-rtc 1
timedatectl set-timezone Asia/Shanghai

sshd_config_file=/etc/ssh/sshd_config
sed -i 's/PermitRootLogin no/PermitRootLogin yes/g' $sshd_config_file
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' $sshd_config_file
systemctl restart sshd

yum install -y git zsh zip epel-release net-tools
# 安装oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
if [[ -f ~/.zshrc ]]; then
    sed -i 's/ZSH_THEME\\=\\"robbyrussell\\"/ZSH_THEME\\=\\"josh\\"/g' ~/.zshrc
    sed -i 's/# DISABLE_AUTO_UPDATE\\=\\"true\\"/DISABLE_AUTO_UPDATE\\=\\"true\\"/g' ~/.zshrc
fi

# 安装v2ray
bash <(curl -L -s https://install.direct/go.sh)
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

# 安装nginx
rpm -ivh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
yum install nginx
web_dir=/var/www/html
mkdir -p $web_dir
cat >$web_dir/index.html <<EOF
<!DOCTYPE html><html lang="en"><head><title></title></head><body><h1 style="text-align: center;">welcome</h1></body></html>
EOF
systemctl start nginx
systemctl enable nginx

# 查看开放端口
for port in 80 443
do
    firewall-cmd --permanent --zone=public --add-port=$port/tcp
done
firewall-cmd --reload
firewall-cmd --zone=public --list-ports

# 修改/etc/selinux/config 文件
# 将SELINUX=enforcing改为SELINUX=disabled
sed -i 's/SELINUX\\=enforcing/SELINUX\\=disabled/g' $sshd_config_file
setsebool -P httpd_can_network_connect 1
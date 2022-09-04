#!/bin/bash

key=`head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 32`
domain=""
run=false
email=""
ssl_crt="public.crt"
ssl_key="private.key"

#获取参数
while getopts "u:k:e:cr" arg
do
	case $arg in
		k)
		    key=$OPTARG
		    ;;
		r) 
		    run=true
		    ;;
		c) 
		    ssl_crt=$OPTARG
		    ;;
		p) 
		    ssl_key=$OPTARG
		    ;;
		d) 
		    domain=$OPTARG 
		    ;;
		e)
		    email=$OPTARG
		    ;;
		?)  
            echo "Unknown argument $OPTARG, exit"
            exit 1
        ;;
        esac
done

#获得系统类型
Get_Dist_Name()
{
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        SYSTEM_VER=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`
        if [[ $systemver -ge 8 ]]; then
            PM='dnf' 
        else 
            PM='yum' 
        fi
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release; then
        DISTRO='RHEL'
        PM='yum'
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        DISTRO='Fedora'
        PM='dnf'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        DISTRO='Debian'
        PM='apt'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        PM='apt'
    else
        DISTRO='unknow'
    fi
}

#安装依赖
function instdpec()
{
	if [ "$1" == "CentOS" ] || [ "$1" == "CentOS7" ];then
		$PM -y groupinstall "Development Tools"
		$PM -y install epel-release
		$PM -y install wget jq curl unzip
	elif [ "$1" == "Debian" ] || [ "$1" == "Raspbian" ] || [ "$1" == "Ubuntu" ];then
		$PM update
		$PM -y install wget jq curl unzip
	else
		echo "The shell can be just supported to install ssr on Centos, Ubuntu and Debian."
		exit 1
	fi
}

Get_Dist_Name

echo "Your OS is $DISTRO"

echo -e "\033[42;34mInstall dependent packages\033[0m"
instdpec $DISTRO;

#获取Trojan-Go下载地址
trojan_download_url=`curl -s https://api.github.com/repos/p4gefau1t/trojan-go/releases/latest | jq -r ".assets[5] | select(.name) | .browser_download_url"`
if [ ! -n "$trojan_download_url" ]; then
echo "Get Trojan-Go Download URL fail. Please try again."
exit 1;
fi

#获取Trojan-API下载地址
trojan_api_url=`curl -s https://api.github.com/repos/misakanetwork2018/trojan-api/releases/latest | jq -r ".assets[] | select(.name) | .browser_download_url"`
if [ ! -n "$trojan_download_url" ]; then
echo "Get Trojan-API Download URL fail. Please try again."
exit 1;
fi

#安装acme.sh（如果请求）
if [ -n "$email" ]; then
    curl  https://get.acme.sh | sh -s email=$email
fi

#下载Trojan-Go并安装
echo -e "\033[42;34mInstall Trojan-Go\033[0m"
wget -O /tmp/trojan-go-linux-amd64.zip $trojan_download_url
mkdir /usr/local/trojan-go
unzip -o /tmp/trojan-go-linux-amd64.zip -d /usr/local/trojan-go/

#写入Trojan-Go配置
cat > /usr/local/trojan-go/server.yaml <<EOF
run-type: server
local-addr: 0.0.0.0
local-port: 443
remote-addr: 127.0.0.1
remote-port: 8085
ssl:
  cert: ${ssl_crt}
  key: ${ssl_key}
  sni: ${domain}
router:
  enabled: true
  block:
    - 'geoip:private'
  geoip: geoip.dat
  geosite: geosite.dat
api:
  enabled: true
  api-addr: 127.0.0.1
  api-port: 10000
EOF

#配置Systemd
cat > /etc/systemd/system/trojan-go.service <<EOF
[Unit]
Description=Trojan Go Server
After=network.target
Wants=network.target
[Service]
Restart=on-failure
Type=simple
PIDFile=/var/run/trojan.pid
ExecStart=/usr/local/trojan-go/trojan-go -config /usr/local/trojan-go/server.yaml
[Install]
WantedBy=multi-user.target
EOF

# install trojan-api
echo -e "\033[42;34mInstall Trojan-Go manyuser manager\033[0m"
# 不能用-c因为可能会误识别为同一个文件的断点续传
wget -O /usr/local/trojan-go/trojan-api $trojan_api_url
chmod a+x /usr/local/trojan-go/trojan-api

#写入Trojan-Go配置
cat > /usr/local/trojan-go/api.yaml <<EOF
web:
  access-key: ${key}
  address: 127.0.0.1
  port: 8085
trojan:
  bin-file: /usr/local/trojan-go/trojan-go
  api-addr: 127.0.0.1
  api-port: 10000
EOF

cat > /etc/systemd/system/trojan-api.service <<EOF
[Unit]
Description=Trojan-Go manyuser manager
After=trojan-go.service
Wants=trojan-go.service
[Service]
Environment='GIN_MODE=release'
Restart=on-failure
Type=simple
LimitNOFILE=40960
LimitNPROC=40960
PIDFile=/var/run/trojan-api.pid
ExecStart=/usr/local/trojan-go/trojan-api -c /usr/local/trojan-go/api.yaml
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable trojan-go.service
systemctl enable trojan-api.service

# Disable and stop firewalld
if [ "$1" == "CentOS" ] || [ "$1" == "CentOS7" ];then
systemctl disable firewalld
systemctl stop firewalld
fi

# If run
if $run ;then
echo -e "\033[42;34mRun Trojan\033[0m"
systemctl start trojan-go.service
systemctl start trojan-api.service
systemctl start caddy.service
fi

#执行acme.sh
if [ -n "$email" ]; then
    acme.sh --issue -d $domain --standalone
    if [ $? -eq 0 ]; then
        acme.sh --install-cert -d $domain \
        --key-file       /usr/local/trojan-go/private.key  \
        --fullchain-file /usr/local/trojan-go/public.crt \
        --reloadcmd     "systemctl restart trojan-go && systemctl restart trojan-api"
    fi
fi

echo "Install successfully. Your key is ${key}"

#!/bin/sh
trojan_api_url=`curl -s https://api.github.com/repos/misakanetwork2018/trojan-api/releases/latest | jq -r ".assets[] | select(.name) | .browser_download_url"`
if [ ! -n "$trojan_api_url" ]; then
echo "Get Trojan Api Download URL Failed. Please try again."
exit;
fi

echo "upgrade trojan-api only"
systemctl stop trojan-api
wget --no-check-certificate -O /usr/local/trojan-go/trojan-api $trojan_api_url
chmod a+x /usr/local/trojan-go/trojan-api
systemctl restart trojan-go
systemctl start trojan-api
echo "Everything is OK!"

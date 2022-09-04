# trojan-one-click-install-sh
Trojan-Go+Trojan-API组合一键安装脚本

## 安装

安装之前请务必保持系统纯净，假如之前安装过Trojan任何版本，可能会导致安装失败

本脚本支持安装acme.sh，一个Let's Encrypt客户端实现，以实现自动生成并配置SSL证书（默认仅支持验证）

目前支持Centos/Fedora/Redhat/Debian/Ubuntu，仅支持64位系统

一键命令（无参数需要自己配置更多内容）：
```
wget --no-check-certificate -O ./install.sh https://raw.githubusercontent.com/misakanetwork2018/trojan-one-click-install-sh/main/install.sh && bash install.sh
```

参数：
```
-k: 认证代码
-r：安装完成后运行
-d: API兼Trojan域名，需提前绑定到服务器（否则Let's Encrypt将会失效）
-e: 电子邮箱，为了申请SSL证书，如不需要Let's Encrypt则不填
-p: SSL私钥路径，若不使用Let's Encrypt则需要填写
-c: SSL证书路径，若不使用Let's Encrypt则需要填写
```

不提供参数的情况下，将会自行生成32位Key，安装最后一句显示

## 升级
一键命令：
```
wget --no-check-certificate -O ./upgrade.sh https://raw.githubusercontent.com/misakanetwork2018/trojan-one-click-install-sh/main/upgrade.sh && bash upgrade.sh
```

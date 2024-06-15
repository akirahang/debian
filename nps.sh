#!/bin/bash

# 克隆nps项目
cd /root/
git clone https://github.com/ehang-io/nps.git

# 交互式获取配置参数
read -p "请输入http_proxy_port的值: " http_proxy_port
read -p "请输入https_proxy_port的值: " https_proxy_port
read -p "请输入web_username的值: " web_username
read -p "请输入web_password的值: " web_password
read -p "请输入web_ip的值: " web_ip
read -p "请输入auth_crypt_key的值: " auth_crypt_key

# 修改配置文件
sed -i "s/^http_proxy_port=.*$/http_proxy_port=${http_proxy_port}/" /root/nps/conf/nps.conf
sed -i "s/^https_proxy_port=.*$/https_proxy_port=${https_proxy_port}/" /root/nps/conf/nps.conf
sed -i "s/^web_username=.*$/web_username=${web_username}/" /root/nps/conf/nps.conf
sed -i "s/^web_password=.*$/web_password=${web_password}/" /root/nps/conf/nps.conf
sed -i "s/^web_ip=.*$/web_ip=${web_ip}/" /root/nps/conf/nps.conf
sed -i "s/^auth_crypt_key=.*$/auth_crypt_key=${auth_crypt_key}/" /root/nps/conf/nps.conf

# 运行Docker容器
docker run -d --name nps --net=host -v /root/nps/conf:/conf --restart=always ffdfgdfg/nps

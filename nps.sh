#!/bin/bash

# 克隆 nps 项目
cd /root/
git clone https://github.com/ehang-io/nps.git

# 提示用户输入配置参数
echo "请输入 web_username:"
read web_username
echo "请输入 web_password:"
read web_password
echo "请输入 web_ip:"
read web_ip
echo "请输入 auth_crypt_key:"
read auth_crypt_key

# 修改 nps 配置文件
sed -i "s/^web_username=.*$/web_username=${web_username}/" /root/nps/conf/nps.conf
sed -i "s/^web_password=.*$/web_password=${web_password}/" /root/nps/conf/nps.conf
sed -i "s/^web_ip=.*$/web_ip=${web_ip}/" /root/nps/conf/nps.conf
sed -i "s/^auth_crypt_key=.*$/auth_crypt_key=${auth_crypt_key}/" /root/nps/conf/nps.conf

# 启动 nps 容器
docker run -d --name nps --net=host -v /root/nps/conf:/conf --restart=always ffdfgdfg/nps

echo "nps 服务端部署完成"

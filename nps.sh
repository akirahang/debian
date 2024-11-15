#!/bin/bash

# 设置 NPS 项目路径
NPS_DIR="/root/nps"

# 检查 Docker Compose 是否已安装
command -v docker >/dev/null 2>&1 || { echo "请先安装 Docker"; exit 1; }

# 克隆 NPS 项目
mkdir -p "$NPS_DIR"
cd "$NPS_DIR"
git clone https://github.com/ehang-io/nps.git . || { echo "克隆 NPS 代码失败"; exit 1; }

# 交互式获取配置参数
read -p "请输入http_proxy_port的值: " http_proxy_port
read -p "请输入https_proxy_port的值: " https_proxy_port
read -p "请输入web_username的值: " web_username
read -p "请输入web_password的值: " web_password
read -p "请输入web_ip的值: " web_ip
read -p "请输入auth_crypt_key的值: " auth_crypt_key

# 修改配置文件
sed -i "s/^http_proxy_port=.*$/http_proxy_port=${http_proxy_port}/" conf/nps.conf
sed -i "s/^https_proxy_port=.*$/https_proxy_port=${https_proxy_port}/" conf/nps.conf
sed -i "s/^web_username=.*$/web_username=${web_username}/" conf/nps.conf
sed -i "s/^web_password=.*$/web_password=${web_password}/" conf/nps.conf
sed -i "s/^web_ip=.*$/web_ip=${web_ip}/" conf/nps.conf
sed -i "s/^auth_crypt_key=.*$/auth_crypt_key=${auth_crypt_key}/" conf/nps.conf

# 运行 Docker 容器
docker run -d --name nps --net=host -v "$NPS_DIR/conf":/conf --restart=always ffdfgdfg/nps || { echo "启动 NPS 容器失败"; exit 1; }

echo "NPS 容器已启动，请访问 http://你的IP:8080 进行管理"

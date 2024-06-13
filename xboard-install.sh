#!/bin/bash

# Xboard Docker Compose 部署脚本

echo "欢迎使用 Xboard Docker Compose 部署脚本"

# 切换到 /root 目录
cd /root

# 获取 Xboard Docker Compose 文件
echo "正在获取 Xboard Docker Compose 文件..."
git clone -b docker-compose --depth 1 https://github.com/cedar2025/Xboard xboard
cd /root/xboard
echo "Xboard Docker Compose 文件获取完成"

# 执行数据库安装命令
echo "正在执行数据库安装命令..."
docker-compose run -it --rm xboard php artisan xboard:install
echo "数据库安装完成，请记录后台地址和管理员账号密码"

# 启动 Xboard
echo "正在启动 Xboard..."
docker-compose up -d
echo "Xboard 启动完成"

# 提示访问网址
echo "请访问 http://你的IP:7001/ 来体验 Xboard"

echo "部署完成！"

exit 0

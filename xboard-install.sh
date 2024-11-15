#!/bin/bash

# 设置 Xboard 项目路径
XBOARD_DIR="/root/xboard"

# 检查 Docker Compose 是否已安装
command -v docker-compose >/dev/null 2>&1 || { echo "请先安装 Docker Compose"; exit 1; }

# 创建 Xboard 项目目录并克隆代码
mkdir -p "$XBOARD_DIR"
cd "$XBOARD_DIR"
git clone -b docker compose --depth 1 https://github.com/cedar2025/Xboard . || { echo "克隆 Xboard 代码失败"; exit 1; }

# 执行数据库安装
echo "正在执行数据库安装..."
docker-compose run --rm xboard php artisan xboard:install
# 提示用户记录信息
read -p "请记录后台地址和管理员账号密码，按 Enter 键继续："

# 启动 Xboard
echo "正在启动 Xboard..."
docker-compose up -d
echo "Xboard 启动完成，请访问 http://你的IP:7001/ 来体验"

# 添加日志功能
echo "部署日志已保存至 $XBOARD_DIR/deploy.log"

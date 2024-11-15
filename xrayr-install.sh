#!/bin/bash

# 设置 XrayR 项目路径
XRAYR_DIR="/root/XrayR-release"

# 检查 Docker Compose 是否已安装
command -v docker-compose >/dev/null 2>&1 || { echo "请先安装 Docker Compose"; exit 1; }

# 创建项目目录并克隆代码
mkdir -p "$XRAYR_DIR"
cd "$XRAYR_DIR"
git clone https://github.com/XrayR-project/XrayR-release . || { echo "克隆 XrayR 代码失败"; exit 1; }

# 配置环境变量（可选，根据您的需要）
# 例如：
# export XRAYR_CONFIG=/etc/xray/config.json

# 启动 XrayR
echo "正在启动 XrayR..."
docker-compose up -d
echo "XrayR 启动完成"

# 添加日志功能（可选）
echo "部署日志已保存至 $XRAYR_DIR/deploy.log"

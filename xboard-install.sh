#!/bin/bash

# 获取用户输入
read -p "请输入Xboard项目路径： " project_path
read -p "请输入管理员邮箱： " admin_email
read -p "是否使用外部Redis？(y/n): " use_external_redis
read -p "是否使用外部MySQL？(y/n): " use_external_mysql
read -p "外部Redis地址（若使用）： " redis_host
read -p "外部Redis端口（若使用）： " redis_port
read -p "外部MySQL地址（若使用）： " mysql_host
read -p "外部MySQL端口（若使用）： " mysql_port
read -p "外部MySQL数据库名（若使用）： " mysql_database
read -p "外部MySQL用户名（若使用）： " mysql_user
read -p "外部MySQL密码（若使用）： " mysql_password

# 检查Docker是否安装
command -v docker >/dev/null 2>&1 || { echo >&2 "Docker未安装，请先安装Docker！"; exit 1; }

# 克隆项目（如需指定分支）
git clone -b docker-compose --depth 1 https://github.com/cedar2025/Xboard $project_path

# 进入项目目录
cd $project_path

# 准备环境变量
if [ "$use_external_redis" = "y" ]; then
  echo "REDIS_HOST=$redis_host" >> .env
  echo "REDIS_PORT=$redis_port" >> .env
fi

if [ "$use_external_mysql" = "y" ]; then
  echo "DB_HOST=$mysql_host" >> .env
  echo "DB_PORT=$mysql_port" >> .env
  echo "DB_DATABASE=$mysql_database" >> .env
  echo "DB_USERNAME=$mysql_user" >> .env
  echo "DB_PASSWORD=$mysql_password" >> .env
fi

# 安装依赖
docker compose up -d

# 执行安装命令
docker compose run -it --rm \
  -e admin_account="$admin_email" \
  -e enable_sqlite=$(if [ "$use_external_mysql" = "y" ]; then echo "false"; else echo "true"; fi) \
  -e enable_redis=$(if [ "$use_external_redis" = "y" ]; then echo "false"; else echo "true"; fi) \
  xboard php artisan xboard:install

# 获取访问地址和密码
echo "安装完成！请记录以下信息："
docker compose logs -f xboard | grep 'http://'

# 启动Xboard
docker compose up -d

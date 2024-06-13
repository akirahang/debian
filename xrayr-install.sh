
#!/bin/bash

# 进入 /root/ 目录
cd /root/

# 克隆 GitHub 仓库
git clone https://github.com/XrayR-project/XrayR-release

# 进入克隆的目录
cd XrayR-release

# 使用 Docker Compose 启动容器并以后台模式运行
docker-compose up -d

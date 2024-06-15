#!/bin/bash

# 提示用户输入 NPC 命令
read -p "请输入 NPC 客户端命令: " npc_command

# 提取参数
server=$(echo "$npc_command" | grep -oP '(?<=-server=)[^ ]+')
vkey=$(echo "$npc_command" | grep -oP '(?<=-vkey=)[^ ]+')
type=$(echo "$npc_command" | grep -oP '(?<=-type=)[^ ]+')

# 构建 docker run 命令
docker_command="docker run -d --restart=always --name npc --net=host yisier1/npc -server=$server -vkey=$vkey -type=$type"

# 执行 docker run 命令
echo "正在运行以下命令启动 Docker 容器 npc:"
echo "$docker_command"
eval "$docker_command"

# 显示运行结果
echo "Docker 容器 npc 已启动，使用以下参数:"
echo "服务器参数: $server"
echo "VKey 参数: $vkey"
echo "类型参数: $type"

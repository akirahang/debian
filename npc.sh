#!/bin/bash

# 提示用户输入命令
read -p "请输入 NPC 命令: " npc_command

# 提取参数
server=$(echo "$npc_command" | grep -oP '(?<=-server=)[^ ]+')
vkey=$(echo "$npc_command" | grep -oP '(?<=-vkey=)[^ ]+')

# 执行 docker run 命令
docker run -d --restart=always --name npc --net=host yisier1/npc $npc_command

# 显示运行结果
echo "Docker 容器 npc 已启动，使用以下参数:"
echo "NPC 命令: $npc_command"
echo "Server 参数: $server"
echo "VKey 参数: $vkey"

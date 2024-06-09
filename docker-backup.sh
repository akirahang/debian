#!/bin/bash

# 函数：备份Docker容器的映射目录
backup_container() {
    clear
    echo "==============================="
    echo "  备份Docker容器的映射目录  "
    echo "==============================="
    echo

    # 列出当前正在运行的Docker容器
    echo "正在列出当前正在运行的Docker容器..."
    running_containers=$(docker ps --format "{{.ID}}: {{.Names}}")
    echo "$running_containers"

    # 提示用户选择要备份的容器
    read -p "请输入要备份的容器编号或名称前四位: " container_input

    # 检查用户输入的容器编号前四位是否有效
    container_id=$(docker ps -q --no-trunc -f "id=${container_input:0:4}" -f status=running)
    if [[ -z "$container_id" ]]; then
        echo "无效的容器编号前四位。"
        return
    fi

    # 获取容器的名称
    container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's#^/##')

    # 获取容器的映射目录
    container_mounts=$(docker inspect --format='{{json .Mounts}}' "$container_id")

    # 解析容器的映射目录路径
    declare -a directories=()
    mapfile -t directories < <(echo "$container_mounts" | jq -r '.[].Source')

    # 检查备份目录是否存在，如果不存在则创建
    backup_directory="/root/backup"
    if [ ! -d "$backup_directory" ]; then
        echo "备份目录 $backup_directory 不存在，正在创建..."
        sudo mkdir -p "$backup_directory"
        echo "备份目录已创建。"
    fi

    # 备份每个映射目录到指定目录
    for directory in "${directories[@]}"; do
        backup_filename="${container_name}_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        echo "正在备份映射目录 $directory 到 $backup_directory/$backup_filename..."
        sudo tar -zcvf "$backup_directory/$backup_filename" -C "$directory" . > /dev/null 2>&1
        echo "备份完成！"
    done

    echo "所有相关映射目录已成功备份到 $backup_directory。"
}

# 函数：显示主菜单
show_main_menu() {
    clear
    echo "==============================="
    echo "      Docker备份工具       "
    echo "==============================="
    echo "1. 备份Docker容器的映射目录"
    echo "0. 退出"
    echo
    read -p "请输入选项编号： " option
    echo

    case $option in
    1) backup_container ;;
    0) exit ;;
    *) echo "无效选项，请输入有效选项。" ;;
    esac

    read -p "按Enter返回主菜单。"
    show_main_menu
}

# 显示主菜单
show_main_menu

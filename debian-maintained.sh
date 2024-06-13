#!/bin/bash

# 函数：检查并安装 sudo
check_and_install_sudo() {
    if ! command -v sudo &> /dev/null; then
        echo "sudo 未安装，正在安装 sudo..."
        apt update
        apt install sudo -y
    fi
}

# 函数：安装 Docker 和 Docker Compose
install_docker_and_compose() {
    echo "==============================="
    echo "      安装 Docker 和 Docker Compose      "
    echo "==============================="
    echo "安装 Docker 和 Docker Compose..."

    # 更新包列表并安装必要的依赖
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common jq

    # 添加 Docker 官方 GPG 密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # 检查是否为 Debian 或 Ubuntu 并添加相应的 Docker 官方仓库
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "debian" ]; then
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        elif [ "$ID" = "ubuntu" ]; then
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        else
            echo "不支持的操作系统: $ID"
            exit 1
        fi
    else
        echo "无法检测操作系统类型"
        exit 1
    fi

    # 更新包列表并安装 Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io

    # 安装 Docker Compose
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    if [[ -x "$(command -v docker)" && -x "$(command -v docker-compose)" ]]; then
        echo "成功安装 Docker 和 Docker Compose"
        echo "Docker 版本: $(docker --version)"
        echo "Docker Compose 版本: $(docker-compose --version)"
    else
        echo "无法安装 Docker 和 Docker Compose"
    fi
}

# 函数：启用 BBR FQ
enable_bbr_fq() {
    echo "==============================="
    echo "        启用 BBR FQ       "
    echo "==============================="
    echo "启用 BBR FQ..."
    if grep -q "net.core.default_qdisc=fq" /etc/default/grub && grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/default/grub; then
        echo "BBR FQ 已配置"
    else
        sudo sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/s/tcp_congestion_control=bbr //' /etc/default/grub
        sudo sed -i '/GRUB_CMDLINE_LINUX/s/="$/ net.core.default_qdisc=fq net.ipv4.tcp_congestion_control=bbr"/' /etc/default/grub
        sudo update-grub
        echo "已启用 BBR FQ"
    fi
}

# 函数：清除所有容器日志
clear_container_logs() {
    echo "==============================="
    echo "    清除所有容器日志    "
    echo "==============================="
    echo "清除所有容器日志..."
    sudo find /var/lib/docker/containers/ -type f -name '*.log' -delete
    echo "容器日志已清除"
}

# 函数：更新和清理系统
update_and_clean_system() {
    echo "==============================="
    echo "    更新和清理系统    "
    echo "==============================="

    if ! command -v sudo &> /dev/null; then
        echo "sudo 未安装，正在安装 sudo..."
        apt update -y
        apt install -y sudo
    else
        echo "sudo 已安装"
    fi

    echo "更新和清理系统..."
    sudo apt update -y
    sudo apt upgrade -y
    sudo apt install -y curl neofetch vim jq git
    sudo apt autoclean
    sudo apt autoremove -y
    sudo find /var/log -type f -delete
    echo "系统更新和清理完成"
}

# 函数：删除特定 Docker 容器和相关映射目录
delete_container() {
    echo "==============================="
    echo "    删除特定 Docker 容器和相关映射目录    "
    echo "==============================="

    # 获取所有容器的ID和名称
    container_list=$(docker ps -a --format "{{.ID}}: {{.Names}}")

    if [ -z "$container_list" ]; then
        echo "没有找到任何 Docker 容器"
        return
    fi

    # 显示所有容器的ID和名称
    echo "当前运行的 Docker 容器列表："
    echo "$container_list"

    read -p "请输入要删除的容器ID： " container_id
    if [ -z "$container_id" ]; then
        echo "未提供容器ID"
        return
    fi

    container_info=$(sudo docker inspect --format='{{json .Mounts}}' "$container_id")
    if [ -z "$container_info" ]; then
        echo "无法检索容器的映射目录信息"
        return
    fi

    declare -a directories=()
    mapfile -t directories < <(echo "$container_info" | jq -r '.[].Source')

    echo "停止和删除容器 $container_id..."
    sudo docker stop "$container_id"
    sudo docker rm "$container_id"
    for directory in "${directories[@]}"; do
        if [ -d "$directory" ]; then
            echo "删除映射目录 $directory..."
            sudo rm -rf "$directory"
        fi
    done
    echo "容器和相关映射目录已删除"
}

# 函数：添加SSH密钥
add_ssh_key() {
    echo "==============================="
    echo "        添加SSH密钥       "
    echo "==============================="
    read -p "请输入用于SSH密钥登录的用户名: " username
    if [ -z "$username" ];then
        echo "未提供用户名"
        return
    fi

    server_ip=$(hostname -I | awk '{print $1}')
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
    curl -s https://raw.githubusercontent.com/cautious1064/ubuntu/main/authorized_keys | ssh "$username@$server_ip" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
    ssh "$username@$server_ip" "chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin without-password/' /etc/ssh/sshd_config
    sudo service ssh restart
    echo "SSH密钥登录已配置"
}

# 函数：调整交换空间大小
adjust_swap_space() {
    echo "==============================="
    echo "       调整交换空间大小       "
    echo "==============================="
    read -p "请输入新的交换空间大小（以MB为单位，输入0表示禁用交换空间）: " new_swap_size
    if ! [[ $new_swap_size =~ ^[0-9]+$ ]]; then
        echo "无效输入"
        return
    fi

    sudo swapoff -a
    if [ "$new_swap_size" -eq 0 ]; then
        sudo sed -i '/swap/d' /etc/fstab
        echo "交换空间已禁用"
        return
    fi

    sudo dd if=/dev/zero of=/swapfile bs=1M count="$new_swap_size"
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
    echo "交换空间大小已调整为 ${new_swap_size}MB"
}

# 函数：修改 /tmp 大小
modify_tmp_size() {
    echo "==============================="
    echo "       修改 /tmp 大小       "
    echo "==============================="
    read -p "请输入新的 /tmp 大小（以MB为单位，建议不小于您预期的使用量）: " new_tmp_size

    if ! [[ $new_tmp_size =~ ^[0-9]+$ ]]; then
        echo "无效输入，必须是一个整数。"
        return 1
    fi

    # 检查是否存在 /tmp 条目，如果存在则先删除
    if grep -q "/tmp" /etc/fstab; then
        sudo sed -i '/\/tmp/d' /etc/fstab
    fi

    # 添加新的 /tmp 条目
    echo "tmpfs /tmp tmpfs defaults,size=${new_tmp_size}M 0 0" | sudo tee -a /etc/fstab

    # 尝试挂载 /tmp
    sudo mount -o remount /tmp

    # 再次检查是否成功挂载 /tmp
    if mount | grep -q "/tmp"; then
        echo "/tmp 大小已修改为 ${new_tmp_size}MB"
    else
        echo "修改 /tmp 大小失败"
        return 1
    fi
}


# 函数：快速部署基础容器
deploy_basic_containers() {
    echo "==============================="
    echo "   快速部署基础容器    "
    echo "==============================="

    # 创建 docker-compose.yml 文件
    cat <<EOF > docker-compose.yml
version: '3'
services:

  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: unless-stopped
    ports:
      - 8000:8000
      - 9443:9443
      - 9000:9000
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
 
  filebrowser:
    image: filebrowser/filebrowser
    container_name: filebrowser
    volumes:
      - /:/srv
    restart: unless-stopped
    ports:
      - 8081:80
      
volumes:
  portainer_data:
    driver: local
EOF

    echo "正在启动基础容器..."
    sudo docker-compose up -d

    if [ $? -eq 0 ]; then
        echo "基础容器已成功部署"
    else
        echo "部署基础容器失败"
    fi
}

backup_directory="/root/docker_backup"

# 函数：备份Docker容器的映射目录
backup_container_volumes() {
    clear
    echo "==============================="
    echo "  备份Docker容器的映射目录  "
    echo "==============================="
    echo

    # 列出当前正在运行的Docker容器
    echo "正在列出当前正在运行的Docker容器..."
    running_containers=$(docker ps --format "{{.ID}}: {{.Names}}")
    echo "$running_containers"
    echo

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
    if [ ! -d "$backup_directory" ]; then
        echo "备份目录 $backup_directory 不存在，正在创建..."
        sudo mkdir -p "$backup_directory"
        echo "备份目录已创建。"
    fi

    # 备份每个映射目录到指定目录
    for directory in "${directories[@]}"; do
        backup_filename="${container_name}_$(date +%Y%m%d_%H%M%S).tar.gz"
        echo "正在备份映射目录 $directory 到 $backup_directory/$backup_filename..."
        sudo tar -zcvf "$backup_directory/$backup_filename" -C "$directory" . > /dev/null 2>&1
        echo "备份完成！"
    done

    echo "所有相关映射目录已成功备份到 $backup_directory。"
    read -p "按 Enter 键返回 Docker 管理菜单..."
}

# 函数：恢复Docker容器的映射目录
restore_container_volumes() {
    clear
    echo "==============================="
    echo "  恢复Docker容器的映射目录  "
    echo "==============================="
    echo

    # 列出备份目录中的所有备份文件
    echo "正在列出备份目录中的所有备份文件..."
    backup_files=($(ls "$backup_directory"/*.tar.gz 2>/dev/null))
    if [ ${#backup_files[@]} -eq 0 ]; then
        echo "没有找到任何备份文件。"
        return
    fi

    for i in "${!backup_files[@]}"; do
        echo "$i) ${backup_files[$i]}"
    done
    echo

    # 提示用户选择要恢复的备份文件
    read -p "请输入要恢复的备份文件序号: " file_index

    if [[ $file_index -ge 0 && $file_index -lt ${#backup_files[@]} ]]; then
        backup_file=${backup_files[$file_index]}
    else
        echo "无效的序号。"
        return
    fi

    # 提示用户输入要恢复到的容器编号或名称前四位
    read -p "请输入要恢复到的容器编号或名称前四位: " container_input

    # 检查用户输入的容器编号前四位是否有效
    container_id=$(docker ps -q --no-trunc -f "id=${container_input:0:4}" -f status=running)
    if [[ -z "$container_id" ]]; then
        echo "无效的容器编号前四位。"
        return
    fi

    # 获取容器的名称
    container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's#^/##')

    # 输出容器名称供用户选择
    echo "要恢复的容器名称：$container_name"

    # 获取容器的映射目录
    container_mounts=$(docker inspect --format='{{json .Mounts}}' "$container_id")

    # 解析容器的映射目录路径
    declare -a directories=()
    mapfile -t directories < <(echo "$container_mounts" | jq -r '.[].Source')

    # 停止容器
    docker stop "$container_id"

    # 恢复每个映射目录
    for directory in "${directories[@]}"; do
        echo "正在恢复映射目录 $directory 从 $backup_file..."
        sudo tar -xzf "$backup_file" -C "$directory" > /dev/null 2>&1
        echo "恢复完成！"
    done

    # 重启容器
    docker start "$container_id"

    echo "所有相关映射目录已成功恢复。"
    read -p "按 Enter 键返回 Docker 管理菜单..."
}


quick_deploy_menu() {
    while true; do
        clear
        echo "==============================="
        echo "      快速部署       "
        echo "==============================="
        echo "1. 快速部署基础容器"
        echo "2. 返回上级菜单"
        echo "==============================="
        read -p "请选择一个选项 (1-2): " deploy_choice

        case $deploy_choice in
            1) deploy_basic_containers ;;
            2) return ;;
            *) echo "无效选项，请重试"; sleep 2 ;;
        esac
    done
}

# 函数：修改DNS设置
modify_dns_settings() {
    clear
    echo "==============================="
    echo "       修改DNS设置       "
    echo "==============================="
    echo

    # 提示用户输入新的DNS服务器地址
    read -p "请输入新的DNS服务器地址（多个地址以空格分隔）: " dns_addresses

    # 检查是否输入了DNS地址
    if [ -z "$dns_addresses" ]; then
        echo "未输入DNS地址。"
        read -p "按Enter键返回系统设置菜单..."
        return
    fi

    # 将DNS地址写入文件
    echo "# Custom DNS servers" | sudo tee /etc/resolv.conf > /dev/null
    for address in $dns_addresses; do
        echo "nameserver $address" | sudo tee -a /etc/resolv.conf > /dev/null
    done

    echo "DNS设置已更新为："
    cat /etc/resolv.conf

    read -p "按Enter键返回系统设置菜单..."
}

# 函数：从云端读取 Docker Compose 文件并部署选择的服务
deploy_cloud_service() {
    # 读取云端 Docker Compose 文件内容
    COMPOSE_URL="https://github.com/akirahang/debian/raw/main/server-compose.yml"
    COMPOSE_CONTENT=$(curl -sSL $COMPOSE_URL)

    # 检查是否成功获取文件内容
    if [ -z "$COMPOSE_CONTENT" ]; then
        echo "错误：无法获取 Docker Compose 文件内容。"
        exit 1
    fi

    # 提取容器名称和对应的 container_name 值
    echo "请选择要安装的容器："
    echo "------------------------------------"
    CONTAINERS=$(echo "$COMPOSE_CONTENT" | sed -n '/^\s*container_name:/ {s/^\s*container_name:\s*//; p}')
    
    # 输出调试信息
    echo "提取的容器名称：$CONTAINERS"

    IFS=$'\n' read -rd '' -a CONTAINER_NAMES <<<"$CONTAINERS"
    if [ ${#CONTAINER_NAMES[@]} -eq 0 ]; then
        echo "错误：未能提取任何容器名称。"
        exit 1
    fi

    for index in "${!CONTAINER_NAMES[@]}"; do
        echo "$(($index + 1)). ${CONTAINER_NAMES[$index]}"
    done
    echo "------------------------------------"
    read -p "请输入要安装的容器序号：" SERVICE_INDEX

    # 检查用户输入的序号是否有效
    if ! [[ "$SERVICE_INDEX" =~ ^[0-9]+$ ]] || [ "$SERVICE_INDEX" -le 0 ] || [ "$SERVICE_INDEX" -gt ${#CONTAINER_NAMES[@]} ]; then
        echo "错误：无效的序号 '$SERVICE_INDEX'。"
        exit 1
    fi

    SERVICE_NAME=${CONTAINER_NAMES[$(($SERVICE_INDEX - 1))]}

    # 执行安装部署操作，并输出详细信息到标准输出
    echo "正在部署容器 '$SERVICE_NAME'..."
    docker-compose -f <(echo "$COMPOSE_CONTENT") up -d "$SERVICE_NAME"

    # 检查部署是否成功
    if [ $? -eq 0 ]; then
        echo "容器 '$SERVICE_NAME' 已成功部署。"

        # 获取容器的映射端口信息并显示
        echo "容器 '$SERVICE_NAME' 的映射端口如下："
        if grep -q "network_mode: host" <<< "$COMPOSE_CONTENT"; then
            HOST_PORTS=$(docker ps --format "{{.Ports}}" --filter "name=$SERVICE_NAME")
            echo "$HOST_PORTS"
        else
            CONTAINER_PORTS=$(docker-compose -f <(echo "$COMPOSE_CONTENT") port "$SERVICE_NAME")
            echo "$CONTAINER_PORTS"
        fi
    else
        echo "错误：部署容器 '$SERVICE_NAME' 失败。"
    fi
}

# 添加任务
add_cron_job() {
    read -p "请输入任务的命令: " command
    read -p "请输入任务的时间表(e.g., '0 2 * * *' 表示每天凌晨2点): " schedule
    (crontab -l; echo "$schedule $command") | crontab -
    echo "任务已添加: $schedule $command"
}

# 删除任务
remove_cron_job() {
    read -p "请输入要删除的任务的命令: " command
    crontab -l | grep -v "$command" | crontab -
    echo "任务已删除: $command"
}

# 列出所有任务
list_cron_jobs() {
    crontab -l
}

# 主菜单函数
#!/bin/bash
# 主菜单函数
show_main_menu() {
    while true; do
        clear
        echo "==============================="
        echo "      脚本功能列表       "
        echo "==============================="
        echo "1. Docker 管理"
        echo "2. 快速部署"
        echo "3. 系统优化"
        echo "4. 系统清理"
        echo "5. 系统设置"
        echo "6. 管理 Crontab 任务"
        echo "7. 退出"
        echo "==============================="
        read -p "请选择一个选项 (1-7): " main_choice

        case $main_choice in
            1) docker_management_menu ;;
            2) quick_deploy_menu ;;
            3) system_optimization_menu ;;
            4) system_cleanup_menu ;;
            5) system_settings_menu ;;
            6) crontab_management_menu ;;
            7) echo "退出脚本"; exit 0 ;;
            *) echo "无效选项，请重试"; sleep 2 ;;
        esac
        read -p "按 Enter 键返回主菜单..."
    done
}

backup_restore_menu() {
    while true; do
        clear
        echo "==============================="
        echo "       Docker 备份/恢复菜单   "
        echo "==============================="
        echo "1) 备份Docker容器的映射目录"
        echo "2) 恢复Docker容器的映射目录"
        echo "3) 返回上级菜单"
        echo
        read -p "请输入选项 (1/2/3): " choice
        case $choice in
            1) backup_container_volumes ;;
            2) restore_container_volumes ;;
            3) break ;;
            *) echo "无效选项，请重试。" ; read -p "按 Enter 键继续..." ;;
        esac
    done
}

docker_management_menu() {
    while true; do
        clear
        echo "==============================="
        echo "      Docker 管理       "
        echo "==============================="
        echo "1. 安装 Docker 和 Docker Compose"
        echo "2. 部署云服务" 
        echo "3. 清除所有容器日志"
        echo "4. 删除特定 Docker 容器和相关映射目录"
        echo "5. 备份/恢复 Docker 容器映射目录"
        echo "6. 返回上级菜单"
        echo "==============================="
        read -p "请选择一个选项 (1-6): " docker_choice

        case $docker_choice in
            1) install_docker_and_compose ;;
            2) deploy_cloud_service ;;
            3) clear_container_logs ;;
            4) delete_container ;;
            5) backup_restore_menu ;;
            6) break ;;
            *) echo "无效选项，请重试"; sleep 2 ;;
        esac
        read -p "按 Enter 键返回 Docker 管理菜单..."
    done
}


system_optimization_menu() {
    while true; do
        clear
        echo "==============================="
        echo "      系统优化       "
        echo "==============================="
        echo "1. 启用 BBR FQ"
        echo "2. 调整交换空间大小"
        echo "3. 修改 /tmp 大小"
        echo "4. 返回上级菜单"
        echo "==============================="
        read -p "请选择一个选项 (1-4): " optimization_choice

        case $optimization_choice in
            1) enable_bbr_fq ;;
            2) adjust_swap_space ;;
            3) modify_tmp_size ;;
            4) break ;;
            *) echo "无效选项，请重试"; sleep 2 ;;
        esac
        read -p "按 Enter 键返回系统优化菜单..."
    done
}

system_cleanup_menu() {
    while true; do
        clear
        echo "==============================="
        echo "      系统清理       "
        echo "==============================="
        echo "1. 更新和清理系统"
        echo "2. 返回上级菜单"
        echo "==============================="
        read -p "请选择一个选项 (1-2): " cleanup_choice

        case $cleanup_choice in
            1) update_and_clean_system ;;
            2) break ;;
            *) echo "无效选项，请重试"; sleep 2 ;;
        esac
        read -p "按 Enter 键返回系统清理菜单..."
    done
}

system_settings_menu() {
    while true; do
        clear
        echo "==============================="
        echo "      系统设置       "
        echo "==============================="
        echo "1. 添加 SSH 密钥"
        echo "2. 修改系统 DNS"
        echo "3. 返回主菜单"
        echo "==============================="
        read -p "请选择一个选项 (1-3): " settings_choice

        case $settings_choice in
            1) add_ssh_key ;;
            2) modify_dns_settings ;;
            3) return ;;
            *) echo "无效选项，请重试"; sleep 2 ;;
        esac
    done
}

crontab_management_menu() {
    while true; do
        clear
        echo "==============================="
        echo "      管理 Crontab 任务       "
        echo "==============================="
        echo "1. 添加一个 crontab 任务"
        echo "2. 删除一个 crontab 任务"
        echo "3. 列出所有 crontab 任务"
        echo "4. 返回上级菜单"
        echo "==============================="
        read -p "请选择一个选项 (1-4): " crontab_choice

        case $crontab_choice in
            1) add_cron_job ;;
            2) remove_cron_job ;;
            3) list_cron_jobs ;;
            4) break ;;
            *) echo "无效选项，请重试"; sleep 2 ;;
        esac
        read -p "按 Enter 键返回 Crontab 管理菜单..."
    done
}
# 主程序入口，运行主菜单
show_main_menu


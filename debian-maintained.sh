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
    sudo apt update
    sudo apt install -y docker.io docker-compose jq

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
    echo "更新和清理系统..."
    sudo apt update -y
    sudo apt upgrade -y
    sudo apt install -y curl neofetch vim jq
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
        echo "无效输入"
        return
    fi

    sudo sed -i '/\/tmp/d' /etc/fstab
    echo "tmpfs /tmp tmpfs defaults,size=${new_tmp_size}M 0 0" | sudo tee -a /etc/fstab
    sudo mount -o remount /tmp
    if grep -q "/tmp" /etc/fstab && mount | grep -q "/tmp"; then
        echo "/tmp 大小已修改为 ${new_tmp_size}MB"
    else
        echo "修改 /tmp 大小失败"
    fi
}

# 函数：显示主菜单
show_main_menu() {
    while true; do
        clear
        echo "==============================="
        echo "      脚本功能列表       "
        echo "==============================="
        echo "1. 安装 Docker 和 Docker Compose"
        echo "2. 启用 BBR FQ"
        echo "3. 清除所有容器日志"
        echo "4. 更新和清理系统"
        echo "5. 删除特定 Docker 容器和相关映射目录"
        echo "6. 添加SSH密钥"
        echo "7. 调整交换空间大小"
        echo "8. 修改 /tmp 大小"
        echo "9. 退出"
        echo "==============================="
        read -p "请选择一个选项 (1-9): " choice

        case $choice in
            1) install_docker_and_compose ;;
            2) enable_bbr_fq ;;
            3) clear_container_logs ;;
            4) update_and_clean_system ;;
            5) delete_container ;;
            6) add_ssh_key ;;
            7) adjust_swap_space ;;
            8) modify_tmp_size ;;
            9) echo "退出脚本"; exit 0 ;;
            *) echo "无效选项，请重试"; sleep 2 ;;
        esac
        read -p "按 Enter 键返回主菜单..."
    done
}

# 主程序
check_and_install_sudo
show_main_menu

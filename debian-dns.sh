#!/bin/bash

# 函数：修改DNS设置
modify_dns() {
    clear
    echo "==============================="
    echo "       修改DNS设置       "
    echo "==============================="
    echo
    read -p "请输入新的DNS服务器地址（多个地址以空格分隔）: " dns_addresses

    # 检查是否输入了DNS地址
    if [ -z "$dns_addresses" ]; then
        echo "未输入DNS地址。"
        return
    fi

    # 将DNS地址写入文件
    echo "# Custom DNS servers" | sudo tee /etc/resolv.conf > /dev/null
    for address in $dns_addresses; do
        echo "nameserver $address" | sudo tee -a /etc/resolv.conf > /dev/null
    done

    echo "DNS设置已更新为："
    cat /etc/resolv.conf
}

# 函数：恢复默认DNS设置
restore_default_dns() {
    clear
    echo "==============================="
    echo "    恢复默认DNS设置    "
    echo "==============================="
    echo
    echo "正在恢复默认DNS设置..."
    sudo cp /etc/resolvconf/resolv.conf.d/original /etc/resolv.conf > /dev/null 2>&1
    echo "默认DNS设置已恢复。"
}

# 函数：显示主菜单
show_main_menu() {
    clear
    echo "==============================="
    echo "      DNS设置工具       "
    echo "==============================="
    echo "1. 修改DNS设置"
    echo "2. 恢复默认DNS设置"
    echo "0. 退出"
    echo
    read -p "请输入选项编号： " option
    echo

    case $option in
    1) modify_dns ;;
    2) restore_default_dns ;;
    0) exit ;;
    *) echo "无效选项，请输入有效选项。" ;;
    esac

    read -p "按Enter返回主菜单。"
    show_main_menu
}

# 显示主菜单
show_main_menu

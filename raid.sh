#!/bin/bash

# 定义日志文件路径
LOG_FILE="/var/log/raid_check.log"

# 获取当前日期和时间
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# RAID状态检查函数
check_raid_status() {
    echo "[$DATE] Checking RAID status..." >> $LOG_FILE
    
    if ! command -v mdadm &> /dev/null
    then
        echo "[$DATE] mdadm not installed. Please install it to manage RAID arrays." >> $LOG_FILE
        echo "mdadm未安装。请先安装mdadm来管理RAID阵列。"
        exit 1
    fi

    RAID_STATUS=$(cat /proc/mdstat)

    echo "[$DATE] RAID Status:" >> $LOG_FILE
    echo "$RAID_STATUS" >> $LOG_FILE
    
    if echo "$RAID_STATUS" | grep -q '\[.*_.*\]'
    then
        echo "[$DATE] WARNING: RAID array is degraded or has issues." >> $LOG_FILE
        echo "警告：RAID阵列降级或存在问题。"
        
        echo "$RAID_STATUS" | mail -s "RAID Array Issue Detected on $HOSTNAME" user@example.com
    else
        echo "[$DATE] RAID array is healthy." >> $LOG_FILE
        echo "RAID阵列健康。"
    fi
}

# 修复RAID阵列函数
repair_raid() {
    echo "[$DATE] Attempting to repair RAID array..." >> $LOG_FILE
    echo "尝试修复RAID阵列..."
    mdadm --assemble --scan >> $LOG_FILE 2>&1
    mdadm --monitor --scan --oneshot >> $LOG_FILE 2>&1
    echo "RAID阵列修复完成。"
}

# 创建RAID阵列并挂载到目录
create_raid() {
    echo "[$DATE] Creating RAID array..." >> $LOG_FILE

    # 选择RAID类型
    echo "请选择RAID类型（1, 5, 6, 10）："
    read -p "输入RAID类型: " raid_type

    # 验证RAID类型
    if [[ ! "$raid_type" =~ ^(1|5|6|10)$ ]]; then
        echo "[$DATE] Invalid RAID type selected: $raid_type" >> $LOG_FILE
        echo "无效的RAID类型，请选择1, 5, 6或10。"
        return
    fi

    # 显示可用设备列表
    echo "可用设备列表："
    lsblk -dno NAME,SIZE | grep -v "NAME"

    # 选择设备
    read -p "请输入要用于RAID的设备（用空格分隔，例如：/dev/sda /dev/sdb）： " devices

    # 验证设备输入
    for device in $devices; do
        if [ ! -b "$device" ]; then
            echo "[$DATE] Invalid device selected: $device" >> $LOG_FILE
            echo "无效设备：$device。请确保输入正确的设备路径。"
            return
        fi
    done

    # 确认创建RAID
    echo "即将创建RAID$raid_type，使用设备：$devices"
    read -p "确认创建？(y/n): " confirm

    if [ "$confirm" != "y" ]; then
        echo "操作已取消。"
        return
    fi

    # 执行RAID创建
    mdadm --create /dev/md0 --level=$raid_type --raid-devices=$(echo $devices | wc -w) $devices >> $LOG_FILE 2>&1

    if [ $? -eq 0 ]; then
        echo "RAID$raid_type 阵列创建成功。"
        echo "[$DATE] RAID$raid_type array created successfully." >> $LOG_FILE
    else
        echo "RAID创建失败，请检查日志以了解详细信息。"
        echo "[$DATE] RAID creation failed." >> $LOG_FILE
        return
    fi

    # 创建文件系统并挂载
    mkfs.ext4 /dev/md0 >> $LOG_FILE 2>&1
    mkdir -p /root/nas
    mount /dev/md0 /root/nas

    if [ $? -eq 0 ]; then
        echo "RAID$raid_type 阵列已挂载到 /root/nas/。"
        echo "[$DATE] RAID$raid_type array mounted to /root/nas/." >> $LOG_FILE
    else
        echo "挂载失败，请检查日志以了解详细信息。"
        echo "[$DATE] RAID mount failed." >> $LOG_FILE
        return
    fi

    # 添加到开机自动挂载
    UUID=$(blkid -s UUID -o value /dev/md0)
    echo "UUID=$UUID /root/nas ext4 defaults,nofail 0 0" >> /etc/fstab

    if [ $? -eq 0 ]; then
        echo "RAID$raid_type 阵列已配置为开机自动挂载。"
        echo "[$DATE] RAID$raid_type array configured for auto-mount at boot." >> $LOG_FILE
    else
        echo "配置开机自动挂载失败，请检查日志以了解详细信息。"
        echo "[$DATE] Auto-mount configuration failed." >> $LOG_FILE
    fi
}

# 清除RAID开机自动挂载功能
clear_raid_mount() {
    UUID=$(blkid -s UUID -o value /dev/md0)

    if [ -z "$UUID" ]; then
        echo "找不到RAID阵列的UUID，请确保RAID阵列已正确创建。"
        return
    fi

    sed -i "\|UUID=$UUID /root/nas ext4 defaults,nofail 0 0|d" /etc/fstab

    if [ $? -eq 0 ]; then
        echo "RAID阵列的开机自动挂载已清除。"
        echo "[$DATE] RAID auto-mount entry removed from /etc/fstab." >> $LOG_FILE
    else
        echo "清除开机自动挂载失败，请检查日志以了解详细信息。"
        echo "[$DATE] Failed to remove auto-mount entry." >> $LOG_FILE
    fi
}

# 查看日志函数
view_logs() {
    echo "显示日志文件内容："
    cat $LOG_FILE
}

# 清除日志文件函数
clear_logs() {
    > $LOG_FILE
    echo "日志文件已清除。"
}

# 显示菜单
show_menu() {
    echo "请选择一个操作："
    echo "1. 检查RAID状态"
    echo "2. 修复RAID阵列"
    echo "3. 创建RAID阵列并挂载"
    echo "4. 清除RAID的开机自动挂载"
    echo "5. 查看日志"
    echo "6. 清除日志"
    echo "7. 退出"
    read -p "输入选项编号: " choice
}

# 主程序入口
while true; do
    show_menu

    case $choice in
        1)
            check_raid_status
            ;;
        2)
            repair_raid
            ;;
        3)
            create_raid
            ;;
        4)
            clear_raid_mount
            ;;
        5)
            view_logs
            ;;
        6)
            clear_logs
            ;;
        7)
            echo "退出程序。"
            exit 0
            ;;
        *)
            echo "无效选项，请重新输入。"
            ;;
    esac
done

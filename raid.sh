#!/bin/bash

# 日志文件
LOG_FILE="/var/log/raid_maintenance.log"
DATE=$(date +"%Y-%m-%d %H:%M:%S")
MOUNT_POINT="/root/nas"

# 检查RAID阵列状态
check_raid_status() {
    echo "[$DATE] Checking RAID array status..." >> $LOG_FILE
    cat /proc/mdstat
    echo "RAID阵列状态："
    cat /proc/mdstat
}

# 显示RAID阵列的详细信息
show_raid_detail() {
    echo "[$DATE] Showing RAID detail..." >> $LOG_FILE
    mdadm --detail /dev/md0
    echo "RAID阵列详细信息："
    mdadm --detail /dev/md0
}

# 删除RAID设备函数
remove_raid_device() {
    show_raid_detail

    # 提示用户选择要删除的设备
    echo "[$DATE] Select the device to remove from RAID array."
    read -p "Enter the device path to remove (e.g., /dev/sdb): " device_to_remove

    # 检查输入的设备路径是否有效
    if [ ! -b "$device_to_remove" ]; then
        echo "Invalid device path: $device_to_remove. Operation cancelled."
        echo "[$DATE] Invalid device path: $device_to_remove. Operation cancelled." >> $LOG_FILE
        return
    fi

    # 从RAID阵列中移除设备
    echo "[$DATE] Removing device $device_to_remove from RAID array..." >> $LOG_FILE
    mdadm --manage /dev/md0 --remove $device_to_remove >> $LOG_FILE 2>&1
    
    if [ $? -eq 0 ]; then
        echo "[$DATE] Device $device_to_remove removed successfully."
        echo "设备 $device_to_remove 已成功移除。"
    else
        echo "[$DATE] Failed to remove device $device_to_remove. Please check the logs for details."
        echo "移除设备 $device_to_remove 失败，请检查日志以了解详细信息。"
        return
    fi

    # 检查RAID阵列状态
    check_raid_status
}

# 修复RAID阵列函数
repair_raid() {
    echo "[$DATE] Attempting to repair RAID array..." >> $LOG_FILE
    
    if ! command -v mdadm &> /dev/null; then
        echo "[$DATE] mdadm not installed. Please install it to manage RAID arrays." >> $LOG_FILE
        echo "mdadm未安装。请先安装mdadm来管理RAID阵列。"
        return
    fi

    # 检查RAID阵列状态
    RAID_STATUS=$(cat /proc/mdstat)
    echo "RAID阵列状态："
    echo "$RAID_STATUS"
    
    # 获取当前RAID类型
    RAID_TYPE=$(mdadm --detail /dev/md0 | grep 'Raid Level' | awk '{print $4}')
    echo "检测到的RAID类型: $RAID_TYPE"
    
    # 检查是否有损坏的磁盘
    FAILED_DISKS=$(mdadm --detail /dev/md0 | grep 'failed' | awk '{print $NF}')
    
    if [ -n "$FAILED_DISKS" ]; then
        echo "检测到损坏的磁盘：$FAILED_DISKS"
        echo "[$DATE] Detected failed disks: $FAILED_DISKS" >> $LOG_FILE
        
        echo "请确保已更换损坏的磁盘。"
        read -p "输入已更换的新磁盘设备路径（如：/dev/sdb）： " new_disk
        
        if [ ! -b "$new_disk" ]; then
            echo "无效的设备路径：$new_disk。操作已取消。"
            echo "[$DATE] Invalid new disk path: $new_disk. Operation cancelled." >> $LOG_FILE
            return
        fi
        
        # 将新磁盘添加到阵列中
        echo "[$DATE] Adding new disk $new_disk to RAID array..." >> $LOG_FILE
        mdadm --manage /dev/md0 --add $new_disk >> $LOG_FILE 2>&1
        
        if [ $? -eq 0 ]; then
            echo "[$DATE] New disk $new_disk added successfully. Rebuilding RAID array..." >> $LOG_FILE
            echo "新磁盘已成功添加到RAID阵列，正在重建RAID阵列..."
        else
            echo "[$DATE] Failed to add new disk $new_disk. Please check the logs for details." >> $LOG_FILE
            echo "添加新磁盘失败，请检查日志以了解详细信息。"
            return
        fi
        
        # 根据不同RAID类型执行不同的修复操作
        case $RAID_TYPE in
            1)
                echo "[$DATE] Rebuilding RAID 1 array..." >> $LOG_FILE
                mdadm --detail /dev/md0 >> $LOG_FILE 2>&1
                ;;
            5)
                echo "[$DATE] Rebuilding RAID 5 array..." >> $LOG_FILE
                mdadm --detail /dev/md0 >> $LOG_FILE 2>&1
                ;;
            6)
                echo "[$DATE] Rebuilding RAID 6 array..." >> $LOG_FILE
                mdadm --detail /dev/md0 >> $LOG_FILE 2>&1
                ;;
            10)
                echo "[$DATE] Rebuilding RAID 10 array..." >> $LOG_FILE
                mdadm --detail /dev/md0 >> $LOG_FILE 2>&1
                ;;
            *)
                echo "[$DATE] Unsupported RAID type: $RAID_TYPE" >> $LOG_FILE
                echo "不支持的RAID类型：$RAID_TYPE。"
                return
                ;;
        esac
        
        # 监控重建进度
        while cat /proc/mdstat | grep -q 'resync\|recover'; do
            echo "[$DATE] RAID array is rebuilding... Please wait." >> $LOG_FILE
            sleep 10
        done
        
        echo "RAID阵列已成功修复并重建。"
        echo "[$DATE] RAID array successfully rebuilt." >> $LOG_FILE
    else
        echo "[$DATE] No failed disks detected. RAID array is healthy." >> $LOG_FILE
        echo "未检测到损坏的磁盘，RAID阵列健康。"
    fi
}

# 清除RAID的开机自动挂载功能
clear_raid_automount() {
    echo "[$DATE] Clearing RAID auto-mount from /etc/fstab..." >> $LOG_FILE

    # 备份 /etc/fstab 文件
    cp /etc/fstab /etc/fstab.bak
    echo "[$DATE] /etc/fstab backup created at /etc/fstab.bak." >> $LOG_FILE

    # 删除 /etc/fstab 中与 RAID 相关的挂载条目
    grep -v "$MOUNT_POINT" /etc/fstab > /tmp/fstab.new && mv /tmp/fstab.new /etc/fstab

    if [ $? -eq 0 ]; then
        echo "[$DATE] RAID auto-mount entry removed from /etc/fstab." >> $LOG_FILE
        echo "RAID开机自动挂载条目已从 /etc/fstab 中移除。"
    else
        echo "[$DATE] Failed to remove RAID auto-mount entry. Please check the logs for details." >> $LOG_FILE
        echo "移除RAID开机自动挂载条目失败，请检查日志以了解详细信息。"
        return
    fi

    # 取消当前挂载
    if mountpoint -q $MOUNT_POINT; then
        umount $MOUNT_POINT
        if [ $? -eq 0 ]; then
            echo "[$DATE] RAID array unmounted from $MOUNT_POINT." >> $LOG_FILE
            echo "RAID阵列已从 $MOUNT_POINT 卸载。"
        else
            echo "[$DATE] Failed to unmount RAID array from $MOUNT_POINT. Please check the logs for details." >> $LOG_FILE
            echo "从 $MOUNT_POINT 卸载RAID阵列失败，请检查日志以了解详细信息。"
        fi
    else
        echo "[$DATE] RAID array is not currently mounted on $MOUNT_POINT." >> $LOG_FILE
    fi
}

# 创建并配置RAID阵列函数
create_raid_array() {
    echo "[$DATE] Creating new RAID array..." >> $LOG_FILE

    # 提示用户选择RAID类型
    echo "请选择要创建的RAID类型："
    echo "1) RAID 0"
    echo "2) RAID 1"
    echo "3) RAID 5"
    echo "4) RAID 6"
    echo "5) RAID 10"
    read -p "请输入选项（1-5）： " raid_choice
    
    case $raid_choice in
        1) RAID_LEVEL=0 ;;
        2) RAID_LEVEL=1 ;;
        3) RAID_LEVEL=5 ;;
        4) RAID_LEVEL=6 ;;
        5) RAID_LEVEL=10 ;;
        *) echo "无效的选择，操作取消。"; return ;;
    esac

    # 提示用户输入要包含在RAID中的设备
    read -p "请输入要包含在RAID阵列中的设备路径（用空格分隔，如 /dev/sdb /dev/sdc）： " raid_devices

    # 检查设备路径是否有效
    for dev in $raid_devices; do
        if [ ! -b "$dev" ]; then
            echo "设备路径 $dev 无效，操作取消。"
            echo "[$DATE] Invalid device path: $dev. Operation cancelled." >> $LOG_FILE
            return
        fi
    done

    # 创建RAID阵列
    echo "[$DATE] Creating RAID $RAID_LEVEL array with devices: $raid_devices..." >> $LOG_FILE
    mdadm --create /dev/md0 --level=$RAID_LEVEL --raid-devices=$(echo $raid_devices | wc -w) $raid_devices >> $LOG_FILE 2>&1
    
    if [ $? -eq 0 ]; then
        echo "[$DATE] RAID $RAID_LEVEL array created successfully." >> $LOG_FILE
        echo "RAID $RAID_LEVEL 阵列已成功创建。"
    else
        echo "[$DATE] Failed to create RAID array. Please check the logs for details." >> $LOG_FILE
        echo "创建RAID阵列失败，请检查日志以了解详细信息。"
        return
    fi

    # 创建文件系统
    echo "[$DATE] Creating filesystem on /dev/md0..." >> $LOG_FILE
    mkfs.ext4 /dev/md0 >> $LOG_FILE 2>&1
    
    if [ $? -eq 0 ]; then
        echo "[$DATE] Filesystem created successfully on /dev/md0." >> $LOG_FILE
        echo "已在 /dev/md0 上成功创建文件系统。"
    else
        echo "[$DATE] Failed to create filesystem on /dev/md0. Please check the logs for details." >> $LOG_FILE
        echo "在 /dev/md0 上创建文件系统失败，请检查日志以了解详细信息。"
        return
    fi

    # 创建挂载点目录
    if [ ! -d "$MOUNT_POINT" ]; then
        mkdir -p $MOUNT_POINT
        echo "[$DATE] Mount point directory $MOUNT_POINT created." >> $LOG_FILE
        echo "挂载点目录 $MOUNT_POINT 已创建。"
    fi

    # 挂载RAID阵列
    mount /dev/md0 $MOUNT_POINT
    
    if [ $? -eq 0 ]; then
        echo "[$DATE] RAID array mounted successfully at $MOUNT_POINT." >> $LOG_FILE
        echo "RAID阵列已成功挂载到 $MOUNT_POINT。"
    else
        echo "[$DATE] Failed to mount RAID array at $MOUNT_POINT. Please check the logs for details." >> $LOG_FILE
        echo "将RAID阵列挂载到 $MOUNT_POINT 失败，请检查日志以了解详细信息。"
        return
    fi

    # 设置开机自动挂载
    echo "/dev/md0 $MOUNT_POINT ext4 defaults 0 0" >> /etc/fstab
    echo "[$DATE] RAID array set to auto-mount on boot." >> $LOG_FILE
    echo "RAID阵列已设置为开机自动挂载。"
}

# 主菜单
main_menu() {
    echo "请选择操作："
    echo "1) 查看RAID状态"
    echo "2) 修复RAID阵列"
    echo "3) 删除RAID设备"
    echo "4) 清除RAID开机自动挂载"
    echo "5) 创建新的RAID阵列"
    echo "6) 退出"
    read -p "请输入选项（1-6）： " choice
    
    case $choice in
        1) check_raid_status ;;
        2) repair_raid ;;
        3) remove_raid_device ;;
        4) clear_raid_automount ;;
        5) create_raid_array ;;
        6) exit 0 ;;
        *) echo "无效的选择，请重试。" ;;
    esac
}

# 脚本入口
main_menu

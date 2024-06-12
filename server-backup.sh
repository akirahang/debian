#!/bin/bash

BACKUP_DIR="/root/backup"

# 交互式菜单函数
show_menu() {
  echo "请选择操作："
  echo "1) 备份容器映射目录"
  echo "2) 恢复容器映射目录"
  echo "3) 退出"
  read -p "请输入选项 (1/2/3): " choice
  case $choice in
    1) backup ;;
    2) restore ;;
    3) exit 0 ;;
    *) echo "无效选项，请重试。" ; show_menu ;;
  esac
}

# 备份函数
backup() {
  read -p "请输入容器名称: " CONTAINER_NAME
  TIMESTAMP=$(date +"%Y%m%d%H%M%S")
  BACKUP_FILE="$BACKUP_DIR/${CONTAINER_NAME}_backup_$TIMESTAMP.tar.gz"

  # 获取容器的映射目录（以 /data 为例）
  MAPPED_DIR=$(docker inspect --format='{{.Mounts}}' $CONTAINER_NAME | grep -oP '(?<=Source:")[^,]*' | grep '/data')

  if [ -z "$MAPPED_DIR" ]; then
    echo "无法找到容器 $CONTAINER_NAME 的映射目录。"
    show_menu
    return
  fi

  # 创建备份
  mkdir -p $BACKUP_DIR
  tar -czf $BACKUP_FILE -C $MAPPED_DIR .

  if [ $? -eq 0 ]; then
    echo "备份成功：$BACKUP_FILE"
  else
    echo "备份失败"
  fi
  show_menu
}

# 恢复函数
restore() {
  read -p "请输入容器名称: " CONTAINER_NAME
  echo "可用的备份文件："
  BACKUP_FILES=($BACKUP_DIR/${CONTAINER_NAME}_backup_*.tar.gz)
  if [ ${#BACKUP_FILES[@]} -eq 0 ]; then
    echo "没有找到任何备份文件。"
    show_menu
    return
  fi

  for i in "${!BACKUP_FILES[@]}"; do
    echo "$i) ${BACKUP_FILES[$i]}"
  done

  read -p "请输入要恢复的备份文件序号: " FILE_INDEX

  if [[ $FILE_INDEX -ge 0 && $FILE_INDEX -lt ${#BACKUP_FILES[@]} ]]; then
    BACKUP_FILE=${BACKUP_FILES[$FILE_INDEX]}
  else
    echo "无效的序号。"
    show_menu
    return
  fi

  MAPPED_DIR=$(docker inspect --format='{{.Mounts}}' $CONTAINER_NAME | grep -oP '(?<=Source:")[^,]*' | grep '/data')

  if [ -z "$MAPPED_DIR" ]; then
    echo "无法找到容器 $CONTAINER_NAME 的映射目录。"
    show_menu
    return
  fi

  # 停止容器
  docker stop $CONTAINER_NAME

  # 清空现有目录内容
  rm -rf $MAPPED_DIR/*

  # 恢复备份
  tar -xzf $BACKUP_FILE -C $MAPPED_DIR

  if [ $? -eq 0 ]; then
    echo "恢复成功：$MAPPED_DIR"
  else
    echo "恢复失败"
  fi

  # 重启容器
  docker start $CONTAINER_NAME
  show_menu
}

# 显示菜单
show_menu

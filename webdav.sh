#!/bin/bash

# 检查并安装必要的软件包
install_dependencies() {
    echo "正在检查并安装依赖项..."
    sudo apt-get update
    sudo apt-get install -y apache2 samba davfs2
    echo "依赖项安装完成。"
}

# 设置WebDAV共享并添加密码保护
setup_webdav() {
    echo "输入要分享的目录路径（绝对路径）:"
    read webdav_dir
    echo "输入WebDAV的访问路径（例如 /webdav/share）:"
    read webdav_path
    echo "输入WebDAV用户名:"
    read webdav_user
    echo "输入WebDAV密码:"
    read -s webdav_password

    # 创建并配置WebDAV目录
    sudo mkdir -p $webdav_dir
    sudo chown -R www-data:www-data $webdav_dir

    # 创建htpasswd文件
    sudo htpasswd -cb /etc/apache2/.htpasswd $webdav_user $webdav_password
    
    # 配置WebDAV站点
    sudo tee /etc/apache2/sites-available/webdav-$webdav_user.conf > /dev/null <<EOL
Alias $webdav_path $webdav_dir

<Directory $webdav_dir>
    AuthType Basic
    AuthName "Restricted Access"
    AuthUserFile /etc/apache2/.htpasswd
    Require valid-user
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>

<IfModule mod_dav.c>
    Dav on
</IfModule>
EOL

    sudo a2enmod dav dav_fs
    sudo a2ensite webdav-$webdav_user
    sudo systemctl reload apache2

    echo "WebDAV共享已设置：访问路径 $webdav_path 指向目录 $webdav_dir"
    echo "$webdav_user:$webdav_path" >> /etc/webdav_shares
}

# 列出并取消WebDAV共享
remove_webdav() {
    if [ ! -f /etc/webdav_shares ]; then
        echo "没有WebDAV共享可供取消。"
        return
    fi

    echo "可取消的WebDAV共享列表："
    nl /etc/webdav_shares

    echo "请输入要取消的分享序号:"
    read share_index
    webdav_user=$(sed -n "${share_index}p" /etc/webdav_shares | cut -d: -f1)

    sudo a2dissite webdav-$webdav_user
    sudo systemctl reload apache2

    sed -i "${share_index}d" /etc/webdav_shares
    echo "WebDAV共享 $webdav_user 已取消。"
}

# 设置Samba共享并添加密码保护
setup_samba() {
    echo "输入要分享的目录路径（绝对路径）:"
    read samba_dir
    echo "输入Samba共享名称:"
    read samba_name
    echo "输入Samba用户名:"
    read samba_user
    echo "输入Samba密码:"
    read -s samba_password

    # 确保用户存在
    if ! id -u $samba_user > /dev/null 2>&1; then
        sudo useradd -M $samba_user
    fi

    echo -e "$samba_password\n$samba_password" | sudo smbpasswd -a $samba_user

    sudo mkdir -p $samba_dir
    sudo chown -R nobody:nogroup $samba_dir
    sudo chmod -R 0775 $samba_dir
    
    # 配置Samba共享
    sudo tee -a /etc/samba/smb.conf > /dev/null <<EOL

[$samba_name]
   path = $samba_dir
   valid users = $samba_user
   browsable = yes
   writable = yes
   guest ok = no
   read only = no
EOL

    sudo systemctl restart smbd

    echo "Samba共享已设置：共享名称 $samba_name 指向目录 $samba_dir"
    echo "$samba_name:$samba_user" >> /etc/samba_shares
}

# 列出并取消Samba共享
remove_samba() {
    if [ ! -f /etc/samba_shares ]; then
        echo "没有Samba共享可供取消。"
        return
    fi

    echo "可取消的Samba共享列表："
    nl /etc/samba_shares

    echo "请输入要取消的分享序号:"
    read share_index
    samba_name=$(sed -n "${share_index}p" /etc/samba_shares | cut -d: -f1)

    sudo sed -i "/^\[$samba_name\]/,+6d" /etc/samba/smb.conf
    sudo systemctl restart smbd

    sed -i "${share_index}d" /etc/samba_shares
    echo "Samba共享 $samba_name 已取消。"
}

# 设置开机自动启动
setup_autostart() {
    echo "[Unit]
Description=Start WebDAV and Samba Shares

[Service]
ExecStart=/usr/sbin/apachectl start && /usr/sbin/smbd start

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/start-shares.service > /dev/null

    sudo systemctl enable start-shares.service
}

# 取消开机自动启动
remove_autostart() {
    if [ -f /etc/systemd/system/start-shares.service ]; then
        sudo systemctl disable start-shares.service
        sudo rm /etc/systemd/system/start-shares.service
        echo "开机自动启动功能已取消。"
    else
        echo "开机自动启动功能未设置。"
    fi
}

# 主菜单
main_menu() {
    echo "请选择操作:"
    echo "1) 设置WebDAV共享"
    echo "2) 取消WebDAV共享"
    echo "3) 设置Samba共享"
    echo "4) 取消Samba共享"
    echo "5) 设置开机自动启动"
    echo "6) 取消开机自动启动"
    echo "7) 退出"
    read choice

    case $choice in
        1) setup_webdav ;;
        2) remove_webdav ;;
        3) setup_samba ;;
        4) remove_samba ;;
        5) setup_autostart ;;
        6) remove_autostart ;;
        7) exit 0 ;;
        *) echo "无效选项，请重新选择。" ;;
    esac
}

# 运行脚本
install_dependencies

while true; do
    main_menu
done

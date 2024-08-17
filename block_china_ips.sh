#!/bin/bash

# 更新并安装必要的软件包
echo "Updating system and installing required packages..."
sudo apt-get update
sudo apt-get install -y ipset xtables-addons-common wget unzip

# 创建目录用于存储GeoIP数据
GEOIP_DIR="/usr/share/xt_geoip"
mkdir -p $GEOIP_DIR
cd $GEOIP_DIR

# 下载GeoIP数据库
echo "Downloading GeoIP database..."
/usr/lib/xtables-addons/xt_geoip_dl

# 构建GeoIP数据
echo "Building GeoIP database..."
/usr/lib/xtables-addons/xt_geoip_build GeoIPCountryWhois.csv .

# 创建ipset集合
echo "Creating ipset 'china'..."
ipset create china hash:net

# 清空现有的ipset集合，避免重复添加
ipset flush china

# 加载中国IP地址段到ipset集合
echo "Loading China IP addresses into ipset..."
for i in $(cat $GEOIP_DIR/GeoIPCountryWhois.csv | grep -i "CN" | awk -F, '{print $1"/"$2}'); do
  ipset add china $i
done

# 添加iptables规则阻止来自中国的IP地址
echo "Setting up iptables rules..."
iptables -I INPUT -m set --match-set china src -j DROP
iptables -I FORWARD -m set --match-set china src -j DROP

# 保存iptables规则
echo "Saving iptables rules..."
iptables-save > /etc/iptables/rules.v4

# 创建自动更新脚本
UPDATE_SCRIPT="/usr/local/bin/update_china_ipset.sh"
echo "Creating update script at $UPDATE_SCRIPT..."
cat << 'EOF' > $UPDATE_SCRIPT
#!/bin/bash

# 更新GeoIP数据库
GEOIP_DIR="/usr/share/xt_geoip"
cd $GEOIP_DIR
/usr/lib/xtables-addons/xt_geoip_dl
/usr/lib/xtables-addons/xt_geoip_build GeoIPCountryWhois.csv .

# 清空并重新加载中国IP地址段到ipset集合
ipset flush china
for i in $(cat $GEOIP_DIR/GeoIPCountryWhois.csv | grep -i "CN" | awk -F, '{print $1"/"$2}'); do
  ipset add china $i
done

# 重新加载iptables规则
iptables -I INPUT -m set --match-set china src -j DROP
iptables -I FORWARD -m set --match-set china src -j DROP

# 保存iptables规则
iptables-save > /etc/iptables/rules.v4
EOF

# 赋予脚本执行权限
chmod +x $UPDATE_SCRIPT

# 设置cron任务每周更新一次
echo "Setting up cron job for weekly updates..."
(crontab -l ; echo "0 3 * * 1 /usr/local/bin/update_china_ipset.sh") | crontab -

echo "Setup complete. Your server is now protected from China-based IP probes."

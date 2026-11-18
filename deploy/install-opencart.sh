#!/usr/bin/env bash
# ============================================================
# OpenCart 4 安装脚本 —— 在服务器上执行（Ubuntu 24.04）
#
# 用法：
#   sudo bash install-opencart.sh <域名> [安装目录]
#   例：sudo bash install-opencart.sh shop.liu-royse.site
#
# 做四件事：
#   1. 装 PHP 8.3 + 扩展 + MariaDB
#   2. 按 1GB 内存做资源限制（数据库、PHP-FPM 都调小）
#   3. 下载 OpenCart 并解压到站点目录
#   4. 建数据库、设权限
# ============================================================
set -euo pipefail

DOMAIN="${1:?用法: install-opencart.sh <域名>}"
WEBROOT="${2:-/var/www/opencart}"
OC_VERSION="4.1.0.4"
DB_NAME="opencart"
DB_USER="oc_user"
DB_PASS="$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)"

echo "==> 1/6 安装 PHP 8.3 + 扩展 + MariaDB"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  php8.3-fpm php8.3-cli php8.3-mysql php8.3-curl php8.3-gd \
  php8.3-mbstring php8.3-xml php8.3-zip php8.3-intl php8.3-opcache \
  mariadb-server unzip wget > /dev/null

echo "==> 2/6 调整数据库内存占用（1GB 机器）"
cat > /etc/mysql/mariadb.conf.d/99-low-memory.cnf <<'CNF'
[mysqld]
innodb_buffer_pool_size = 64M
innodb_log_buffer_size  = 8M
innodb_flush_method     = O_DIRECT
key_buffer_size         = 16M
max_connections         = 30
thread_cache_size       = 4
query_cache_type        = 0
performance_schema      = OFF
tmp_table_size          = 16M
max_heap_table_size     = 16M
CNF
systemctl enable mariadb > /dev/null 2>&1
systemctl restart mariadb
echo "    MariaDB 内存上限已限制"

echo "==> 3/6 调整 PHP-FPM 进程数（1GB 机器）"
POOL=/etc/php/8.3/fpm/pool.d/www.conf
sed -i 's/^pm = .*/pm = ondemand/' "$POOL"
sed -i 's/^pm.max_children = .*/pm.max_children = 5/' "$POOL"
sed -i 's/^;pm.process_idle_timeout = .*/pm.process_idle_timeout = 10s/' "$POOL"
grep -q '^pm.process_idle_timeout' "$POOL" || echo 'pm.process_idle_timeout = 10s' >> "$POOL"
systemctl enable php8.3-fpm > /dev/null 2>&1
systemctl restart php8.3-fpm

echo "==> 4/6 下载 OpenCart ${OC_VERSION}"
TMP=$(mktemp -d)
wget -q -O "$TMP/oc.zip" \
  "https://github.com/opencart/opencart/releases/download/${OC_VERSION}/opencart-${OC_VERSION}.zip"
unzip -q "$TMP/oc.zip" -d "$TMP/src"
# 解压后结构：<root>/upload/* 与 <root>/storage/
SRC_UPLOAD=$(find "$TMP/src" -maxdepth 2 -type d -name upload | head -1)
SRC_STORAGE=$(find "$TMP/src" -maxdepth 2 -type d -name storage | head -1)
[ -n "$SRC_UPLOAD" ] || { echo "未找到 upload 目录，压缩包结构异常"; exit 1; }

rm -rf "$WEBROOT"
mkdir -p "$WEBROOT"
cp -a "$SRC_UPLOAD/." "$WEBROOT/"

if [ -n "$SRC_STORAGE" ]; then
  mkdir -p "$WEBROOT/storage"
  cp -a "$SRC_STORAGE/." "$WEBROOT/storage/"
fi
rm -rf "$TMP"

echo "==> 5/6 建库授权"
mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

echo "==> 6/6 设置权限"
chown -R www-data:www-data "$WEBROOT"
find "$WEBROOT" -type d -exec chmod 755 {} \;
find "$WEBROOT" -type f -exec chmod 644 {} \;
# 安装程序需要写入这两个文件
[ -f "$WEBROOT/config.php" ] && chmod 666 "$WEBROOT/config.php"
[ -f "$WEBROOT/admin/config.php" ] && chmod 666 "$WEBROOT/admin/config.php"
chmod -R 775 "$WEBROOT/storage" 2>/dev/null || true
chmod -R 775 "$WEBROOT/image" 2>/dev/null || true

{
  echo "OpenCart 部署信息 $(date '+%F %T')"
  echo "域名     : ${DOMAIN}"
  echo "站点目录 : ${WEBROOT}"
  echo "数据库名 : ${DB_NAME}"
  echo "数据库用户: ${DB_USER}"
  echo "数据库密码: ${DB_PASS}"
  echo "版本     : OpenCart ${OC_VERSION}"
} | tee /root/opencart-info.txt

echo ""
echo "==> 完成。当前内存占用："
free -h | head -2

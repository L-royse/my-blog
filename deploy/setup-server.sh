#!/usr/bin/env bash
# ============================================================
# 服务器初始化 —— 在本地执行，初始化 AWS EC2 (Ubuntu 22.04)
#
# 用法：
#   bash deploy/setup-server.sh <域名> <服务器公网IP> <SSH密钥路径> [SSH用户]
#
# 例：
#   bash deploy/setup-server.sh blog.example.com 12.34.56.78 ~/.ssh/aws.pem ubuntu
#
# 完成的事：
#   1. 安装 Nginx + certbot
#   2. 添加 1GB swap（1G 内存机器必备，防止 OOM）
#   3. 创建 /var/www/blog 并写入站点配置
#   4. 提示申请 HTTPS 证书
# ============================================================
set -euo pipefail

DOMAIN="${1:?用法: setup-server.sh <域名> <服务器IP> <SSH密钥路径> [SSH用户]}"
SERVER_IP="${2:?缺少服务器公网 IP}"
SSH_KEY="${3:?缺少 SSH 密钥路径}"
SSH_USER="${4:-ubuntu}"

TARGET="${SSH_USER}@${SERVER_IP}"
SSH_OPTS=(-i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

echo ">>> 1/4 测试 SSH 连接 ${TARGET}"
ssh "${SSH_OPTS[@]}" "${TARGET}" "echo 'SSH OK: ' && . /etc/os-release && echo \$PRETTY_NAME"

echo ">>> 2/4 上传 Nginx 站点配置"
scp "${SSH_OPTS[@]}" "$(dirname "$0")/nginx-blog.conf" "${TARGET}:/tmp/blog.conf"

echo ">>> 3/4 服务器初始化（安装 Nginx、加 swap、启用站点）"
ssh "${SSH_OPTS[@]}" "${TARGET}" "DOMAIN='${DOMAIN}' bash -s" <<'REMOTE_SH'
set -euo pipefail

# ---------- swap：1G 内存机器必备 ----------
if ! sudo swapon --show | grep -q /swapfile; then
  echo "  添加 1GB swap..."
  sudo fallocate -l 1G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile > /dev/null
  sudo swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi
echo "  swap: $(free -h | awk '/Swap/{print $2}')"

# ---------- 安装 Nginx ----------
if ! command -v nginx >/dev/null; then
  echo "  安装 nginx + certbot..."
  sudo apt-get update -y -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nginx certbot python3-certbot-nginx
fi

# ---------- 站点目录 ----------
sudo mkdir -p /var/www/blog
sudo chown -R www-data:www-data /var/www/blog

# ---------- 写入配置 ----------
sudo sed "s/__DOMAIN__/${DOMAIN}/g" /tmp/blog.conf | sudo tee /etc/nginx/sites-available/blog.conf > /dev/null
sudo ln -sf /etc/nginx/sites-available/blog.conf /etc/nginx/sites-enabled/blog.conf
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl enable nginx > /dev/null 2>&1
sudo systemctl reload nginx

# ---------- 防火墙 ----------
if command -v ufw >/dev/null && sudo ufw status | grep -q "Status: active"; then
  sudo ufw allow OpenSSH || true
  sudo ufw allow 'Nginx Full' || true
fi

echo "  服务器初始化完成"
REMOTE_SH

echo ">>> 4/4 完成"
echo ""
echo "接下来："
echo "  1. 把域名 ${DOMAIN} 的 DNS 解析到 ${SERVER_IP}"
echo "     并在 AWS 安全组放行 22 / 80 / 443 端口"
echo "  2. 上传站点文件："
echo "     DOMAIN=${DOMAIN} SERVER_IP=${SERVER_IP} SSH_KEY=${SSH_KEY} bash deploy/deploy.sh"
echo "  3. 域名解析生效后申请证书："
echo "     ssh -i ${SSH_KEY} ${TARGET} \"sudo certbot --nginx -d ${DOMAIN} --agree-tos -m 你的邮箱 --redirect -n\""

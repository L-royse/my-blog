#!/usr/bin/env bash
# ============================================================
# 一键部署 —— 本地构建并上传到服务器
#
# 用法：
#   DOMAIN=blog.example.com SERVER_IP=12.34.56.78 SSH_KEY=~/.ssh/aws.pem bash deploy/deploy.sh
#
# 为什么在本地构建？
#   1G 内存跑 Astro 构建容易 OOM；本地构建快，产物仅几百 KB
# ============================================================
set -euo pipefail

DOMAIN="${DOMAIN:?请设置 DOMAIN=你的域名}"
SERVER_IP="${SERVER_IP:?请设置 SERVER_IP=服务器公网IP}"
SSH_KEY="${SSH_KEY:?请设置 SSH_KEY=密钥路径}"
SSH_USER="${SSH_USER:-ubuntu}"
REMOTE_DIR="${REMOTE_DIR:-/var/www/blog}"

cd "$(dirname "$0")/../"

echo ">>> 1/4 本地构建"
npm run build

echo ">>> 2/4 检查产物"
[ -f dist/index.html ] || { echo "构建失败：dist/index.html 不存在"; exit 1; }
du -sh dist

echo ">>> 3/4 上传"
rsync -avz --delete \
  -e "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=accept-new" \
  dist/ "${SSH_USER}@${SERVER_IP}:/tmp/blog-dist/"

echo ">>> 4/4 同步到站点目录并重载 Nginx"
ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new "${SSH_USER}@${SERVER_IP}" \
  "sudo rsync -a --delete /tmp/blog-dist/ ${REMOTE_DIR}/ \
   && sudo chown -R www-data:www-data ${REMOTE_DIR} \
   && sudo nginx -t && sudo systemctl reload nginx \
   && rm -rf /tmp/blog-dist"

echo ""
echo ">>> 部署完成：https://${DOMAIN}"

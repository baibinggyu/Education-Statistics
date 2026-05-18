#!/bin/bash
set -e

echo "=== Edu Server Debian 12 部署 ==="

# 1. 检查 Python 版本
echo "[1/5] 检查 Python..."
python3 --version | grep -q "3\.1[12]" || {
    echo "需要 Python 3.11+，当前: $(python3 --version)"
    exit 1
}

# 2. 安装 MariaDB（如果未安装）
echo "[2/5] 检查 MariaDB..."
dpkg -l mariadb-server >/dev/null 2>&1 || {
    echo "安装 MariaDB..."
    sudo apt update && sudo apt install -y mariadb-server
    sudo systemctl enable --now mariadb
}

# 3. 创建数据库和用户
echo "[3/5] 初始化数据库..."
source .env 2>/dev/null || true
sudo mariadb -e "DROP USER IF EXISTS 'edu_user'@'localhost';" 2>/dev/null || true
sudo mariadb -e "CREATE USER 'edu_user'@'localhost' IDENTIFIED BY '$education_statistics_passwd';"
sudo mariadb -e "CREATE DATABASE IF NOT EXISTS edu_server_database CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -e "GRANT ALL PRIVILEGES ON edu_server_database.* TO 'edu_user'@'localhost';"
sudo mariadb -e "FLUSH PRIVILEGES;"
sudo mariadb -e "SELECT user, host FROM mysql.user WHERE user='edu_user';"

# 4. 创建 Python 虚拟环境
echo "[4/5] 配置 Python venv..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 5. 复制环境变量文件
echo "[5/5] 检查 .env..."
[ -f .env ] || {
    cp .env.example .env
    echo "请编辑 .env 文件填入实际值"
}

echo ""
echo "=== 部署完成 ==="
echo "启动方式："
echo "  ./run.sh"
echo ""
echo "注册 systemd 服务："
echo "  sudo cp edu-server.service /etc/systemd/system/"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable --now edu-server"

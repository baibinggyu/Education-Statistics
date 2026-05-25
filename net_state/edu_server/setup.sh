#!/bin/bash
set -euo pipefail

echo "=== Edu Server setup ==="

if [ ! -f .env ]; then
    cp .env.example .env
fi

set -a
source .env
set +a

DB_NAME="${education_statistics_db_name:-edu_server_database}"
DB_USER="${education_statistics_db_user:-edu_user}"
DB_PASS="${education_statistics_passwd:-edu123456}"

echo "Creating database '$DB_NAME' and user '$DB_USER'..."
sudo mariadb -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mariadb -e "ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mariadb -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
sudo mariadb -e "FLUSH PRIVILEGES;"

echo ""
echo "Done. Start with: ./run.sh"

#!/bin/bash
# 确保 MariaDB 用户存在且使用密码认证（幂等：DROP IF EXISTS + CREATE）
sudo mariadb -e "DROP USER IF EXISTS 'edu_user'@'localhost';" 2>/dev/null
sudo mariadb -e "CREATE USER 'edu_user'@'localhost' IDENTIFIED BY '$education_statistics_passwd';" 2>/dev/null
sudo mariadb -e "GRANT ALL PRIVILEGES ON edu_server_database.* TO 'edu_user'@'localhost';" 2>/dev/null
sudo mariadb -e "FLUSH PRIVILEGES;" 2>/dev/null

HOST="${edu_server_host:-0.0.0.0}"
PORT="${edu_server_port:-55555}"

uvicorn main:app --host "$HOST" --port "$PORT"

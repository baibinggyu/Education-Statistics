#!/bin/bash
export education_statistics_db_host="${education_statistics_db_host:-127.0.0.1}"
export education_statistics_db_port="${education_statistics_db_port:-3306}"
export education_statistics_db_name="${education_statistics_db_name:-edu_server_database}"
export education_statistics_db_user="${education_statistics_db_user:-root}"
export education_statistics_passwd="${education_statistics_passwd:-mysql_pw}"
export education_statistics_secret_key="${education_statistics_secret_key:-edu-server-default-secret-change-in-production}"
export ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-sk-493da862d37c4215b659e0d11dd7eb30}"
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://api.deepseek.com/anthropic}"
export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-deepseek-v4-pro}"
export AI_PROXY_TIMEOUT_SECONDS="${AI_PROXY_TIMEOUT_SECONDS:-60}"

HOST="${edu_server_host:-127.0.0.1}"
PORT="${edu_server_port:-55555}"

uvicorn main:app --host "$HOST" --port "$PORT"

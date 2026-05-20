#!/bin/bash
# EduStat_qml 启动脚本
# 从 shell 启动时 ~/.bashrc 已加载；从桌面菜单启动时手动加载

# ------ 加载 DeepSeek API 配置 ------
if [ -f "$HOME/.bashrc" ]; then
    # 从 .bashrc 提取 ANTHROPIC_* 变量（避免加载整个 bashrc 可能产生的副作用）
    eval "$(grep -E '^export (ANTHROPIC_|DEEPSEEK_API_KEY)' "$HOME/.bashrc")"
fi

# ------ 中文输入法 ------
if [ -z "$QT_IM_MODULE" ]; then
    case "$XMODIFIERS" in
        *fcitx*|*Fcitx*) export QT_IM_MODULE=fcitx ;;
        *ibus*|*IBus*) export QT_IM_MODULE=ibus ;;
        *) [ -n "$GTK_IM_MODULE" ] && export QT_IM_MODULE="$GTK_IM_MODULE" ;;
    esac
fi

# ------ 启动应用 ------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/build/EduStat_qml" "$@"

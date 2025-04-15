#!/bin/bash
#
# x-ui 管理脚本 —— 针对 docker-3xui.sh 安装的 x-ui 项目
#
# 支持的命令：
#   start     - 启动 x-ui
#   stop      - 停止 x-ui
#   restart   - 重启 x-ui
#   status    - 显示 x-ui 运行状态
#   settings  - 显示当前配置
#   enable    - 设置 x-ui 开机自启（添加 crontab @reboot 项）
#   disable   - 禁用自启
#   log       - 查看 x-ui 日志（默认读取 /var/log/x-ui.log）
#   banlog    - 显示 Fail2ban（或其他）日志（若适用）
#   update    - 更新 x-ui（重新运行安装脚本）
#   legacy    - 切换至 legacy 版本（暂未实现）
#   install   - 重新安装 x-ui
#   uninstall - 卸载 x-ui
#   setport   - 修改 x-ui 服务端口
#

# 主程序及目录路径
XUI_BIN="/usr/local/x-ui/x-ui"
XUI_DIR="/usr/local/x-ui"
# 日志文件路径（建议在 docker-3xui.sh 中启动时做日志重定向）
LOG_FILE="/var/log/x-ui.log"
# 安装脚本的位置（根据你实际放置 docker-3xui.sh 的位置调整）
INSTALL_SCRIPT="/mnt/data/docker-3xui.sh"

# 判断 x-ui 是否正在运行
function is_running() {
    pgrep -f "$XUI_BIN" > /dev/null
}

# 启动 x-ui：如果未运行则后台启动，并将输出写入 LOG_FILE
function start_xui() {
    if is_running; then
        echo "x-ui 已经在运行。"
    else
        echo "正在启动 x-ui..."
        nohup "$XUI_BIN" >> "$LOG_FILE" 2>&1 &
        sleep 1
        if is_running; then
            echo "x-ui 启动成功。"
        else
            echo "x-ui 启动失败，请检查日志！"
        fi
    fi
}

# 停止 x-ui：通过 pkill
function stop_xui() {
    if is_running; then
        echo "正在停止 x-ui..."
        pkill -f "$XUI_BIN"
        sleep 1
        if is_running; then
            echo "x-ui 停止失败。"
        else
            echo "x-ui 已停止。"
        fi
    else
        echo "x-ui 当前未运行。"
    fi
}

# 重启 x-ui：先停止再启动
function restart_xui() {
    echo "正在重启 x-ui..."
    stop_xui
    start_xui
}

# 查看 x-ui 运行状态
function status_xui() {
    if is_running; then
        echo "x-ui 正在运行："
        pgrep -fl "$XUI_BIN"
    else
        echo "x-ui 没有在运行。"
    fi
}

# 显示 x-ui 当前配置信息
function show_settings() {
    if [ -x "$XUI_BIN" ]; then
        "$XUI_BIN" setting -show true
    else
        echo "未找到 x-ui 主程序（$XUI_BIN）。"
    fi
}

# 设置 x-ui 开机自启：通过添加 @reboot 项到 crontab
function enable_autostart() {
    if crontab -l 2>/dev/null | grep -q "$XUI_BIN"; then
        echo "自启已启用。"
    else
        (crontab -l 2>/dev/null; echo "@reboot nohup $XUI_BIN >> $LOG_FILE 2>&1 &") | crontab -
        echo "自启已启用（重启后生效）。"
    fi
}

# 禁用自启：删除 crontab 中包含 x-ui 的那一行
function disable_autostart() {
    crontab -l 2>/dev/null | grep -v "$XUI_BIN" | crontab -
    echo "自启已禁用。"
}

# 显示 x-ui 日志文件的最后 50 行
function show_log() {
    if [ -f "$LOG_FILE" ]; then
        tail -n 50 "$LOG_FILE"
    else
        echo "未找到日志文件（$LOG_FILE）。"
    fi
}

# 显示 Fail2ban 或其他相关日志（如不适用，可进行相应扩展）
function show_banlog() {
    echo "Fail2ban 日志未启用或不适用于此安装。"
}

# 更新 x-ui：调用安装脚本重新安装（确保更新到最新版本）
function update_xui() {
    echo "正在更新 x-ui..."
    if [ -x "$INSTALL_SCRIPT" ]; then
        "$INSTALL_SCRIPT"
    else
        echo "未找到安装脚本：$INSTALL_SCRIPT"
    fi
}

# 切换至 legacy 版本（这里作为占位项，具体逻辑根据需求补充）
function legacy_mode() {
    echo "Legacy 模式尚未实现。"
}

# 重新安装 x-ui
function install_xui() {
    echo "重新安装 x-ui..."
    if [ -x "$INSTALL_SCRIPT" ]; then
        "$INSTALL_SCRIPT"
    else
        echo "未找到安装脚本：$INSTALL_SCRIPT"
    fi
}

# 卸载 x-ui：停止服务并删除安装目录，同时清理自启项
function uninstall_xui() {
    echo "正在卸载 x-ui..."
    stop_xui
    rm -rf "$XUI_DIR"
    crontab -l 2>/dev/null | grep -v "$XUI_BIN" | crontab -
    echo "x-ui 已卸载。"
}

# 修改服务端口
function set_port_xui() {
    if [ -z "$2" ]; then
        echo "用法: $0 setport <新端口>"
        exit 1
    fi
    new_port="$2"
    echo "正在将 x-ui 服务端口修改为 $new_port ..."
    # 调用 x-ui 的 setting 命令仅修改端口（假设 x-ui 支持单独更新端口配置）
    "$XUI_BIN" setting -port "$new_port"
    if [ $? -eq 0 ]; then
        echo "端口修改成功。建议重启 x-ui 使新配置生效。"
    else
        echo "端口修改失败，请检查 x-ui 日志。"
    fi
}

# 主命令分发
case "$1" in
    start)
        start_xui
        ;;
    stop)
        stop_xui
        ;;
    restart)
        restart_xui
        ;;
    status)
        status_xui
        ;;
    settings)
        show_settings
        ;;
    enable)
        enable_autostart
        ;;
    disable)
        disable_autostart
        ;;
    log)
        show_log
        ;;
    banlog)
        show_banlog
        ;;
    update)
        update_xui
        ;;
    legacy)
        legacy_mode
        ;;
    install)
        install_xui
        ;;
    uninstall)
        uninstall_xui
        ;;
    setport)
        set_port_xui "$@"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|settings|enable|disable|log|banlog|update|legacy|install|uninstall|setport}"
        exit 1
        ;;
esac

exit 0

#!/bin/bash

# 你的 x-ui.sh 脚本：已去除 systemd 依赖版本

# 原有颜色定义保留
red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

function LOGD() { echo -e "${yellow}[DEG] $* ${plain}"; }
function LOGE() { echo -e "${red}[ERR] $* ${plain}"; }
function LOGI() { echo -e "${green}[INF] $* ${plain}"; }

# 检查 root
[[ $EUID -ne 0 ]] && LOGE "ERROR: You must be root to run this script!" && exit 1

# 检查 x-ui 是否运行
check_status() {
    if pgrep -f '/usr/local/x-ui/x-ui' >/dev/null 2>&1; then
        return 0  # 正在运行
    else
        return 1  # 未运行
    fi
}

# 启动 x-ui
start() {
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui 已经运行，无需再次启动。"
    else
        nohup /usr/local/x-ui/x-ui >/dev/null 2>&1 &
        sleep 2
        check_status && LOGI "x-ui 启动成功。" || LOGE "x-ui 启动失败，建议查看日志排查。"
    fi
}

# 停止 x-ui
stop() {
    check_status
    if [[ $? == 1 ]]; then
        LOGI "x-ui 已经停止，无需再次停止。"
    else
        pkill -f '/usr/local/x-ui/x-ui'
        sleep 2
        check_status && LOGE "x-ui 可能未完全停止，请手动检查。" || LOGI "x-ui 已成功停止。"
    fi
}

# 重启 x-ui
restart() {
    pkill -f '/usr/local/x-ui/x-ui'
    sleep 2
    nohup /usr/local/x-ui/x-ui >/dev/null 2>&1 &
    sleep 2
    check_status && LOGI "x-ui 重启成功。" || LOGE "x-ui 重启失败，请查看日志。"
}

# 查看状态
status() {
    check_status
    if [[ $? == 0 ]]; then
        echo -e "x-ui 状态：${green}运行中${plain}" && ps -ef | grep '/usr/local/x-ui/x-ui' | grep -v grep
    else
        echo -e "x-ui 状态：${red}未运行${plain}"
    fi
}

# 查看日志
show_log() {
    log_file="/usr/local/x-ui/x-ui.log"
    if [[ -f "$log_file" ]]; then
        tail -n 100 -f "$log_file"
    else
        LOGE "找不到日志文件: $log_file"
    fi
}

# 开机启动提示
enable() {
    echo -e "${yellow}提示：无 systemd 环境，建议手动将 x-ui 启动命令加入 /etc/rc.local 实现开机自启。${plain}"
}
disable() {
    echo -e "${yellow}提示：无 systemd 环境，取消开机启动请手动修改 /etc/rc.local。${plain}"
}

# 卸载
uninstall() {
    stop
    rm -rf /usr/local/x-ui /etc/x-ui
    echo -e "${green}x-ui 已成功卸载。${plain}"
}

# 主菜单入口
case "$1" in
    start) start ;;
    stop) stop ;;
    restart) restart ;;
    status) status ;;
    log) show_log ;;
    enable) enable ;;
    disable) disable ;;
    uninstall) uninstall ;;
    *)
        echo "用法: $0 {start|stop|restart|status|log|enable|disable|uninstall}"
        ;;
esac

#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 常量定义
PID_FILE="/var/run/x-ui.pid"
LOG_FILE="/var/log/x-ui.log"
CONFIG_PATH="/usr/local/x-ui/bin/config.json"

# 日志函数
LOGD() { echo -e "${yellow}[DEG] $* ${plain}"; }
LOGE() { echo -e "${red}[ERR] $* ${plain}"; }
LOGI() { echo -e "${green}[INF] $* ${plain}"; }

# 状态检查
check_status() {
    [ -f $PID_FILE ] && ps -p $(cat $PID_FILE) >/dev/null 2>&1
}

# 服务管理
start() {
    if check_status; then
        LOGI "服务已在运行中 (PID: $(cat $PID_FILE))"
        return 0
    fi
    nohup /usr/local/x-ui/x-ui > $LOG_FILE 2>&1 &
    echo $! > $PID_FILE
    sleep 2
    if check_status; then
        LOGI "启动成功"
        return 0
    else
        rm -f $PID_FILE
        LOGE "启动失败，查看日志: tail -n 50 $LOG_FILE"
        return 1
    fi
}

stop() {
    if check_status; then
        kill -9 $(cat $PID_FILE) && rm -f $PID_FILE
        LOGI "服务已停止"
        return 0
    fi
    LOGI "服务未在运行"
    return 1
}

restart() {
    stop
    start || return 1
    LOGI "重启成功"
}

# 配置管理
set_port() {
    read -p "输入新端口 (1-65535): " port
    [[ ! $port =~ ^[0-9]+$ ]] && LOGE "无效端口" && return 1
    (( port < 1 || port > 65535 )) && LOGE "端口超出范围" && return 1
    
    if /usr/local/x-ui/x-ui setting -port $port; then
        LOGI "端口已修改为 $port，正在重启..."
        restart
    else
        LOGE "端口修改失败"
        return 1
    fi
}

show_config() {
    echo -e "\n${green}=== 当前配置信息 ===${plain}"
    /usr/local/x-ui/x-ui setting -show
    echo -e "${green}====================${plain}\n"
}

# 安装管理
uninstall() {
    read -p "确定要完全卸载x-ui吗？[y/n]: " confirm
    [[ $confirm != "y" ]] && return
    bash /usr/local/x-ui/x-ui.sh uninstall
    rm -rf /usr/local/x-ui /usr/bin/x-ui $PID_FILE $LOG_FILE
    LOGI "x-ui 已完全卸载"
}

reinstall() {
    read -p "确定要重新安装吗？(保留配置)[y/n]: " confirm
    [[ $confirm != "y" ]] && return
    stop
    rm -rf /usr/local/x-ui/x-ui /usr/local/x-ui/bin/xray-*
    curl -sL https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install.sh | bash
    start
}

# 状态显示
status() {
    if check_status; then
        echo -e "运行状态: ${green}运行中${plain} (PID: $(cat $PID_FILE))"
        echo -e "运行时长: $(ps -p $(cat $PID_FILE) -o etime=)"
    else
        echo -e "运行状态: ${red}未运行${plain}"
    fi
    echo -e "日志文件: $LOG_FILE"
}

# 帮助信息
show_help() {
    echo -e "${green}x-ui 管理命令:${plain}"
    echo "  start       - 启动服务"
    echo "  stop        - 停止服务"
    echo "  restart     - 重启服务"
    echo "  status      - 查看状态"
    echo "  set-port    - 修改端口"
    echo "  show-config - 显示配置"
    echo "  reinstall   - 重新安装"
    echo "  uninstall   - 完全卸载"
    echo "  log         - 查看日志"
}

# 主逻辑
case "$1" in
    start)       start ;;
    stop)        stop ;;
    restart)     restart ;;
    status)      status ;;
    set-port)    set_port ;;
    show-config) show_config ;;
    reinstall)   reinstall ;;
    uninstall)   uninstall ;;
    log)         tail -f $LOG_FILE ;;
    *)           show_help ;;
esac

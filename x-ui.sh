#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 常量定义
PID_FILE="/var/run/x-ui.pid"
LOG_FILE="/var/log/x-ui.log"
CONFIG_PATH="/usr/local/x-ui/bin/config.json"

LOGD() { echo -e "${yellow}[DEG] $* ${plain}"; }
LOGE() { echo -e "${red}[ERR] $* ${plain}"; }
LOGI() { echo -e "${green}[INF] $* ${plain}"; }
LOGW() { echo -e "${yellow}[WAR] $* ${plain}"; }

check_status() {
    if [ -f $PID_FILE ] && ps -p $(cat $PID_FILE) >/dev/null; then
        return 0
    else
        [ -f $PID_FILE ] && rm -f $PID_FILE
        return 1
    fi
}

start() {
    check_status
    if [ $? -eq 0 ]; then
        LOGI "面板已运行 (PID: $(cat $PID_FILE))"
        return 0
    fi
    
    nohup /usr/local/x-ui/x-ui > $LOG_FILE 2>&1 &
    echo $! > $PID_FILE
    sleep 2
    
    if check_status; then
        LOGI "启动成功"
        return 0
    else
        LOGE "启动失败，检查日志: tail -n 50 $LOG_FILE"
        return 1
    fi
}

stop() {
    check_status
    if [ $? -ne 0 ]; then
        LOGI "面板已停止"
        return 0
    fi
    
    kill -9 $(cat $PID_FILE) && rm -f $PID_FILE
    sleep 1
    
    if check_status; then
        LOGE "停止失败"
        return 1
    else
        LOGI "已成功停止"
        return 0
    fi
}

restart() {
    stop
    start
    [ $? -eq 0 ] && LOGI "重启成功" || LOGE "重启失败"
}

status() {
    check_status
    if [ $? -eq 0 ]; then
        LOGI "运行状态: ${green}运行中${plain} (PID: $(cat $PID_FILE))"
        echo -e "运行时长: $(ps -p $(cat $PID_FILE) -o etime=)"
    else
        LOGI "运行状态: ${red}未运行${plain}"
    fi
    echo -e "日志文件: $LOG_FILE"
}

set_port() {
    check_status || return 1
    current_port=$(jq -r '.port' $CONFIG_PATH)
    
    echo -n "当前端口: $current_port，输入新端口 (1-65535): "
    read new_port
    [[ ! $new_port =~ ^[0-9]+$ ]] && LOGE "无效端口" && return 1
    [ $new_port -lt 1 -o $new_port -gt 65535 ] && LOGE "端口超出范围" && return 1
    
    jq ".port = $new_port" $CONFIG_PATH > tmp.json && mv tmp.json $CONFIG_PATH
    restart
    LOGI "端口已修改为 $new_port"
}

show_config() {
    check_status || return 1
    echo -e "${green}=== 当前配置信息 ===${plain}"
    /usr/local/x-ui/x-ui setting -show
    echo -e "${green}====================${plain}"
}

uninstall() {
    read -p "确定要完全卸载吗？此操作不可逆！[y/n]: " confirm
    [[ $confirm != "y" ]] && return
    
    stop
    rm -rf /usr/local/x-ui /usr/bin/x-ui $PID_FILE $LOG_FILE
    LOGI "x-ui 已完全卸载"
}

show_menu() {
    echo -e "
  ${green}x-ui 面板管理脚本${plain}
  ${green}0.${plain} 退出脚本
————————————————
  ${green}1.${plain} 安装 x-ui
  ${green}2.${plain} 更新 x-ui
  ${green}3.${plain} 卸载 x-ui
————————————————
  ${green}4.${plain} 重置用户名密码
  ${green}5.${plain} 重置面板设置
  ${green}6.${plain} 设置面板端口
  ${green}7.${plain} 查看当前面板信息
————————————————
  ${green}8.${plain} 启动 x-ui
  ${green}9.${plain} 停止 x-ui
  ${green}10.${plain} 重启 x-ui
  ${green}11.${plain} 查看 x-ui 状态
  ${green}12.${plain} 查看 x-ui 日志
————————————————
  ${green}13.${plain} 设置 x-ui 开机自启
  ${green}14.${plain} 取消 x-ui 开机自启
————————————————
  ${green}15.${plain} 一键安装 bbr
  ${green}16.${plain} 申请SSL证书
  ${green}17.${plain} 配置定时任务
    "
    echo && read -p "请输入选择 [0-17]: " num

    case "$num" in
    0) exit 0 ;;
    1) install_x-ui ;;
    2) update_x-ui ;;
    3) uninstall ;;
    4) reset_user ;;
    5) reset_config ;;
    6) set_port ;;
    7) show_config ;;
    8) start ;;
    9) stop ;;
    10) restart ;;
    11) status ;;
    12) show_log ;;
    13) enable ;;
    14) disable ;;
    15) install_bbr ;;
    16) ssl_cert_issue ;;
    17) cron_jobs ;;
    *) LOGE "无效输入" ;;
    esac
}

# 命令行参数处理
if [[ $# -gt 0 ]]; then
    case $1 in
    "start") start ;;
    "stop") stop ;;
    "restart") restart ;;
    "status") status ;;
    "set-port") set_port ;;
    "show-config") show_config ;;
    "log") tail -f $LOG_FILE ;;
    "uninstall") uninstall ;;
    *) show_menu ;;
    esac
else
    show_menu
fi

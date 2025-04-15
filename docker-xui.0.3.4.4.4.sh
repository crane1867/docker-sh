#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# [原有系统检测代码保持不变...]

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar jq -y
    else
        apt install wget curl tar jq -y
    fi
}

# 新增PID文件路径
PID_FILE="/var/run/x-ui.pid"

start_service() {
    if [ -f $PID_FILE ]; then
        echo -e "${yellow}x-ui 已经在运行中${plain}"
        return
    fi
    nohup /usr/local/x-ui/x-ui > /var/log/x-ui.log 2>&1 &
    echo $! > $PID_FILE
    echo -e "${green}x-ui 已启动${plain}"
}

stop_service() {
    if [ ! -f $PID_FILE ]; then
        echo -e "${yellow}x-ui 未在运行中${plain}"
        return
    fi
    kill -9 $(cat $PID_FILE)
    rm -f $PID_FILE
    echo -e "${green}x-ui 已停止${plain}"
}

restart_service() {
    stop_service
    sleep 1
    start_service
}

config_after_install() {
    # [原有配置代码保持不变...]
}

install_x-ui() {
    stop_service
    cd /usr/local/
    
    # [原有下载解压代码保持不变...]
    
    # 移除systemd相关代码
    # rm -f /etc/systemd/system/x-ui.service
    
    # 安装管理脚本
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/FranzKafkaYu/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    
    config_after_install
    
    # 创建日志文件
    touch /var/log/x-ui.log
    chmod 666 /var/log/x-ui.log
    
    start_service
    echo -e "${green}x-ui v${last_version}${plain} 安装完成，面板已启动"
    
    # [原有帮助信息保持不变...]
}

echo -e "${green}开始安装${plain}"
install_base
install_x-ui $1

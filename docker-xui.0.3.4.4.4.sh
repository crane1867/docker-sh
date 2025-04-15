#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# 检查root权限
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# 系统检测（修复语法结构）
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif grep -Eqi "debian" /etc/issue; then
    release="debian"
elif grep -Eqi "ubuntu" /etc/issue; then
    release="ubuntu"
elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
    release="centos"
elif grep -Eqi "debian" /proc/version; then
    release="debian"
elif grep -Eqi "ubuntu" /proc/version; then
    release="ubuntu"
elif grep -Eqi "centos|red hat|redhat" /proc/version; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" 
    exit 1
fi  # 此处为第54行修复点

# 架构检测
arch=$(arch)
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "s390x" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
else
    arch="amd64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

# ... (后续内容保持不变，确保所有语法结构完整) ...

# 系统版本检测
os_version=""
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

# 系统版本校验
if [[ x"${release}" == x"centos" && ${os_version} -le 6 ]]; then
    echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
elif [[ x"${release}" == x"ubuntu" && ${os_version} -lt 16 ]]; then
    echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
elif [[ x"${release}" == x"debian" && ${os_version} -lt 8 ]]; then
    echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
fi

# 服务管理变量
PID_FILE="/var/run/x-ui.pid"
LOG_FILE="/var/log/x-ui.log"

install_base() {
    echo -e "${green}正在安装基础依赖...${plain}"
    if [[ x"${release}" == x"centos" ]]; then
        yum install -y wget curl tar jq
    else
        apt install -y wget curl tar jq
    fi
}

start_service() {
    if [ -f $PID_FILE ]; then
        pid=$(cat $PID_FILE)
        if ps -p $pid > /dev/null; then
            echo -e "${yellow}x-ui 已经在运行中${plain}"
            return
        fi
    fi
    nohup /usr/local/x-ui/x-ui > $LOG_FILE 2>&1 &
    echo $! > $PID_FILE
    echo -e "${green}x-ui 已启动${plain}"
}

stop_service() {
    if [ ! -f $PID_FILE ]; then
        echo -e "${yellow}x-ui 未在运行中${plain}"
        return
    fi
    pid=$(cat $PID_FILE)
    kill -9 $pid && rm -f $PID_FILE
    echo -e "${green}x-ui 已停止${plain}"
}

restart_service() {
    stop_service
    sleep 1
    start_service
}

config_after_install() {
    echo -e "${yellow}正在初始化安全配置...${plain}"
    read -p "是否立即配置账户和端口？[y/n]: " config_confirm
    if [[ $config_confirm =~ ^[Yy]$ ]]; then
        read -p "设置管理员账户: " config_account
        read -p "设置管理员密码: " config_password
        read -p "设置面板端口 (1-65535): " config_port
        /usr/local/x-ui/x-ui setting -username $config_account -password $config_password -port $config_port
        echo -e "${green}初始配置已设置${plain}"
    else
        random_user=$(head -c 6 /dev/urandom | base64)
        random_pass=$(head -c 6 /dev/urandom | base64)
        random_port=$((RANDOM%20000+10000))
        /usr/local/x-ui/x-ui setting -username $random_user -password $random_pass -port $random_port
        echo -e "${red}随机生成登录信息：${plain}"
        echo -e "用户名: ${green}$random_user${plain}"
        echo -e "密码:   ${green}$random_pass${plain}"
        echo -e "端口:   ${red}$random_port${plain}"
    fi
}

uninstall_xui() {
    echo -e "${yellow}正在卸载x-ui...${plain}"
    stop_service
    rm -rf /usr/local/x-ui
    rm -f /usr/bin/x-ui /var/log/x-ui.log $PID_FILE
    echo -e "${green}x-ui 已完全卸载${plain}"
}

install_x-ui() {
    stop_service
    cd /usr/local/
    
    # 获取最新版本
    last_version=$(curl -sL https://api.github.com/repos/FranzKafkaYu/x-ui/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
    [ -z "$last_version" ] && last_version=$1
    
    echo -e "${green}正在下载 x-ui v${last_version}...${plain}"
    wget -q --no-check-certificate -O x-ui-linux-${arch}.tar.gz \
        https://github.com/FranzKafkaYu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz

    # 清除旧版本
    rm -rf x-ui/ x-ui-linux-${arch}.tar.gz
    
    # 解压安装
    tar zxvf x-ui-linux-${arch}.tar.gz
    rm -f x-ui-linux-${arch}.tar.gz
    mv x-ui /usr/local/
    
    # 安装管理脚本
    wget -q --no-check-certificate -O /usr/bin/x-ui \
        https://raw.githubusercontent.com/crane1867/docker-sh/refs/heads/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui /usr/bin/x-ui
    
    # 初始化配置
    touch $LOG_FILE && chmod 666 $LOG_FILE
    config_after_install
    
    # 启动服务
    start_service
    
    # 显示帮助信息
    echo -e "\n${green}安装完成！管理命令：${plain}"
    echo -e "启动服务:    x-ui start"
    echo -e "停止服务:    x-ui stop"
    echo -e "查看状态:    x-ui status"
    echo -e "修改配置:    x-ui set-port"
    echo -e "完全卸载:    x-ui uninstall"
}

# 主安装流程
echo -e "\n${green}===== x-ui 安装程序 =====${plain}"
install_base
install_x-ui $1

#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# 检查root权限
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# 系统检测
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

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

# 系统版本校验
os_version=""
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

# 进程管理变量
PID_FILE="/var/run/x-ui.pid"
LOG_FILE="/var/log/x-ui.log"

function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install -y wget curl tar jq
    else
        apt install -y wget curl tar jq
    fi
}

start_service() {
    if [ -f $PID_FILE ] && ps -p $(cat $PID_FILE) >/dev/null; then
        LOGI "服务已在运行 (PID: $(cat $PID_FILE))"
        return 0
    fi
    nohup /usr/local/x-ui/x-ui > $LOG_FILE 2>&1 &
    echo $! > $PID_FILE
    sleep 2
    if [ -f $PID_FILE ] && ps -p $(cat $PID_FILE) >/dev/null; then
        LOGI "启动成功"
        return 0
    else
        LOGE "启动失败"
        return 1
    fi
}

stop_service() {
    if [ -f $PID_FILE ]; then
        kill -9 $(cat $PID_FILE) && rm -f $PID_FILE
        LOGI "服务已停止"
        return 0
    fi
    LOGI "服务未运行"
    return 1
}

config_after_install() {
    LOGI "正在进行安全初始化..."
    read -p "是否立即配置账户和端口？[y/n]: " config_confirm
    if [[ $config_confirm =~ ^[Yy]$ ]]; then
        read -p "设置管理员账户: " config_account
        read -p "设置管理员密码: " config_password
        while true; do
            read -p "设置面板端口 (1-65535): " config_port
            [[ $config_port =~ ^[0-9]+$ ]] && [ $config_port -ge 1 -a $config_port -le 65535 ] && break
            LOGE "端口号无效！"
        done
        /usr/local/x-ui/x-ui setting -username $config_account -password $config_password -port $config_port
        LOGI "初始配置已设置"
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

install_x-ui() {
    stop_service
    cd /usr/local/

    last_version=$(curl -Ls "https://api.github.com/repos/FranzKafkaYu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [ -z "$last_version" ] && last_version=$1

    LOGI "正在下载 x-ui v${last_version}..."
    wget -O x-ui-linux-${arch}.tar.gz https://github.com/FranzKafkaYu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
    if [ $? -ne 0 ]; then
        LOGE "下载失败，请检查网络连接！"
        exit 1
    fi

    rm -rf x-ui/
    tar zxvf x-ui-linux-${arch}.tar.gz
    if [ $? -ne 0 ]; then
        LOGE "解压失败，文件可能损坏！"
        exit 1
    fi
    rm -f x-ui-linux-${arch}.tar.gz

    mv x-ui /usr/local/
    chmod +x /usr/local/x-ui/x-ui
    chmod +x /usr/local/x-ui/bin/xray-linux-${arch}

    wget -O /usr/bin/x-ui https://raw.githubusercontent.com/crane1867/docker-sh/refs/heads/main/x-ui.sh
    chmod +x /usr/bin/x-ui

    touch $LOG_FILE && chmod 666 $LOG_FILE
    config_after_install

    if start_service; then
        LOGI "=============== 安装成功 ==============="
        LOGI "管理命令: x-ui"
        LOGI "日志文件: tail -f $LOG_FILE"
    else
        LOGE "=============== 安装失败 ==============="
    fi
}

echo -e "${green}===== x-ui 安装程序 ====="
install_base
install_x-ui $1

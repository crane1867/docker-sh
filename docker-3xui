#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

xui_home="/usr/local/x-ui"
xui_bin="/usr/local/x-ui/x-ui"
pid_file="/var/run/x-ui.pid"
log_file="/var/log/x-ui.log"

# 检查root权限
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} Please use root user\n" && exit 1

# 系统检测
check_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        release=$ID
    else
        echo -e "${red}Unsupported OS${plain}" && exit 1
    fi
    echo -e "OS: ${green}${PRETTY_NAME}${plain}"
}

# 架构检测
check_arch() {
    case "$(uname -m)" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l)  arch="armv7" ;;
        *)       echo -e "${red}Unsupported architecture${plain}" && exit 1 ;;
    esac
    echo -e "Arch: ${green}${arch}${plain}"
}

# 安装依赖
install_deps() {
    echo -e "${yellow}Installing dependencies...${plain}"
    
    # 自动检测包管理器
    if command -v apt-get >/dev/null 2>&1; then
        echo -e "${green}Detected APT package manager${plain}"
        apt-get update
        apt-get install -y wget tar
    elif command -v yum >/dev/null 2>&1; then
        echo -e "${green}Detected YUM package manager${plain}"
        yum install -y wget tar
    elif command -v dnf >/dev/null 2>&1; then
        echo -e "${green}Detected DNF package manager${plain}"
        dnf install -y wget tar
    elif command -v apk >/dev/null 2>&1; then
        echo -e "${green}Detected APK package manager${plain}"
        apk add --no-cache wget tar
    elif command -v pacman >/dev/null 2>&1; then
        echo -e "${green}Detected Pacman package manager${plain}"
        pacman -Sy --noconfirm wget tar
    else
        echo -e "${red}Unsupported package manager! Try manual install:${plain}"
        echo -e "Please install these packages manually:"
        echo -e "1. wget"
        echo -e "2. tar"
        exit 1
    fi
}

# 生成随机字符串
gen_random_str() {
    head -c 100 /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $1 | head -n 1
}

# 进程管理
start_service() {
    if [ -f $pid_file ]; then
        echo -e "${yellow}Stopping existing service...${plain}"
        kill -9 $(cat $pid_file) 2>/dev/null
    fi
    
    echo -e "${green}Starting x-ui...${plain}"
    nohup $xui_bin > $log_file 2>&1 &
    echo $! > $pid_file
    sleep 2
    
    if ps -p $(cat $pid_file) > /dev/null; then
        echo -e "${green}Service started successfully! PID: $(cat $pid_file)${plain}"
    else
        echo -e "${red}Failed to start service! Check ${log_file}${plain}"
        exit 1
    fi
}

# 配置初始化
init_config() {
    mkdir -p $xui_home
    echo -e "${yellow}Generating initial config...${plain}"
    
    local admin_user=$(gen_random_str 8)
    local admin_pass=$(gen_random_str 12)
    local panel_port=$(shuf -i 20000-65000 -n 1)
    local web_path=$(gen_random_str 10)
    
    cat > $xui_home/config.json <<EOF
{
  "web": {
    "port": $panel_port,
    "secret": "",
    "basePath": "/$web_path",
    "username": "$admin_user",
    "password": "$admin_pass"
  }
}
EOF

    echo -e "${green}========================================"
    echo -e " Panel Address: http://[YOUR_IP]:$panel_port/$web_path"
    echo -e " Username: $admin_user"
    echo -e " Password: $admin_pass"
    echo -e "========================================${plain}"
}

# 安装核心
install_core() {
    echo -e "${yellow}Downloading 3x-ui...${plain}"
    latest_ver=$(curl -s https://api.github.com/repos/MHSanaei/3x-ui/releases/latest | grep tag_name | cut -d'"' -f4)
    [ -z "$latest_ver" ] && echo -e "${red}Failed to get version${plain}" && exit 1
    
    wget -qO /tmp/x-ui.tar.gz "https://github.com/MHSanaei/3x-ui/releases/download/$latest_ver/x-ui-linux-$arch.tar.gz"
    [ $? -ne 0 ] && echo -e "${red}Download failed${plain}" && exit 1
    
    echo -e "${green}Extracting files...${plain}"
    tar xzf /tmp/x-ui.tar.gz -C /usr/local/
    rm -f /tmp/x-ui.tar.gz
    chmod +x $xui_bin
    
    # 创建管理脚本
    cat > /usr/local/bin/x-ui <<'EOF'
#!/bin/bash
case $1 in
start)
    nohup /usr/local/x-ui/x-ui > /var/log/x-ui.log 2>&1 &
    echo $! > /var/run/x-ui.pid
    ;;
stop)
    [ -f /var/run/x-ui.pid ] && kill -9 $(cat /var/run/x-ui.pid)
    ;;
restart)
    $0 stop
    sleep 1
    $0 start
    ;;
status)
    if [ -f /var/run/x-ui.pid ]; then
        if ps -p $(cat /var/run/x-ui.pid) > /dev/null; then
            echo "Service is running (PID: $(cat /var/run/x-ui.pid))"
        else
            echo "Service is not running (PID file exists)"
        fi
    else
        echo "Service is not running"
    fi
    ;;
log)
    tail -f /var/log/x-ui.log
    ;;
*)
    echo "Usage: $0 {start|stop|restart|status|log}"
    exit 1
    ;;
esac
EOF

    chmod +x /usr/local/bin/x-ui
}

# 主安装流程
main() {
    check_os
    check_arch
    install_deps
    install_core
    init_config
    start_service
    
    echo -e "\n${green}Installation completed!${plain}"
    echo -e "Manage commands:"
    echo -e "  x-ui start    - Start service"
    echo -e "  x-ui stop     - Stop service"
    echo -e "  x-ui restart  - Restart service"
    echo -e "  x-ui status   - Check running status"
    echo -e "  x-ui log      - View real-time logs"
}

main

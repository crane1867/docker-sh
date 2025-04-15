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
config_file="$xui_home/config.json"

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
        apt-get install -y wget tar jq
    elif command -v yum >/dev/null 2>&1; then
        echo -e "${green}Detected YUM package manager${plain}"
        yum install -y wget tar jq
    elif command -v dnf >/dev/null 2>&1; then
        echo -e "${green}Detected DNF package manager${plain}"
        dnf install -y wget tar jq
    elif command -v apk >/dev/null 2>&1; then
        echo -e "${green}Detected APK package manager${plain}"
        apk add --no-cache wget tar jq
    elif command -v pacman >/dev/null 2>&1; then
        echo -e "${green}Detected Pacman package manager${plain}"
        pacman -Sy --noconfirm wget tar jq
    else
        echo -e "${red}Unsupported package manager! Try manual install:${plain}"
        echo -e "Please install these packages manually:"
        echo -e "1. wget"
        echo -e "2. tar"
        echo -e "3. jq (for JSON processing)"
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

# 停止服务
stop_service() {
    if [ -f $pid_file ]; then
        echo -e "${yellow}Stopping x-ui...${plain}"
        kill -9 $(cat $pid_file) 2>/dev/null
        rm -f $pid_file
        echo -e "${green}Service stopped successfully!${plain}"
    else
        echo -e "${red}Service is not running${plain}"
    fi
}

# 重启服务
restart_service() {
    stop_service
    start_service
}

# 修改服务端口
change_port() {
    if [ ! -f $config_file ]; then
        echo -e "${red}Config file not found!${plain}"
        return 1
    fi
    
    echo -e "${yellow}Current panel port: $(jq -r '.web.port' $config_file)${plain}"
    read -p "Enter new panel port (default: 2053): " new_port
    new_port=${new_port:-2053}
    
    # 验证端口
    if ! [[ $new_port =~ ^[0-9]+$ ]] || [ $new_port -lt 1 ] || [ $new_port -gt 65535 ]; then
        echo -e "${red}Invalid port number!${plain}"
        return 1
    fi
    
    # 修改配置
    jq ".web.port = $new_port" $config_file > $config_file.tmp && mv $config_file.tmp $config_file
    echo -e "${green}Port changed to $new_port${plain}"
    
    # 重启服务
    restart_service
}

# 重置面板设置
reset_panel() {
    echo -e "${yellow}Resetting panel settings...${plain}"
    stop_service
    
    local admin_user=$(gen_random_str 8)
    local admin_pass=$(gen_random_str 12)
    local panel_port=$(shuf -i 20000-65000 -n 1)
    local web_path=$(gen_random_str 10)
    
    cat > $config_file <<EOF
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
    
    start_service
}

# 查看当前配置
show_config() {
    if [ ! -f $config_file ]; then
        echo -e "${red}Config file not found!${plain}"
        return 1
    fi
    
    echo -e "${green}====== Current x-ui Configuration ======${plain}"
    echo -e "Panel Port: $(jq -r '.web.port' $config_file)"
    echo -e "Username: $(jq -r '.web.username' $config_file)"
    echo -e "Password: $(jq -r '.web.password' $config_file)"
    echo -e "Base Path: $(jq -r '.web.basePath' $config_file)"
    echo -e "PID File: $pid_file"
    echo -e "Log File: $log_file"
    echo -e "Binary Path: $xui_bin"
    echo -e "Config Path: $config_file"
    echo -e "${green}=======================================${plain}"
}

# 卸载服务
uninstall_service() {
    echo -e "${yellow}Uninstalling x-ui...${plain}"
    stop_service
    
    rm -rf $xui_home
    rm -f $pid_file
    rm -f $log_file
    rm -f /usr/local/bin/x-ui
    
    echo -e "${green}x-ui has been uninstalled successfully!${plain}"
}

# 配置初始化
init_config() {
    mkdir -p $xui_home
    echo -e "${yellow}Generating initial config...${plain}"
    
    read -p "Enter panel port (default: random between 20000-65000): " custom_port
    if [ -z "$custom_port" ]; then
        custom_port=$(shuf -i 20000-65000 -n 1)
    fi
    
    local admin_user=$(gen_random_str 8)
    local admin_pass=$(gen_random_str 12)
    local web_path=$(gen_random_str 10)
    
    cat > $config_file <<EOF
{
  "web": {
    "port": $custom_port,
    "secret": "",
    "basePath": "/$web_path",
    "username": "$admin_user",
    "password": "$admin_pass"
  }
}
EOF
    
    echo -e "${green}========================================"
    echo -e " Panel Address: http://[YOUR_IP]:$custom_port/$web_path"
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

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

xui_home="/usr/local/x-ui"
xui_bin="/usr/local/x-ui/x-ui"
pid_file="/var/run/x-ui.pid"
log_file="/var/log/x-ui.log"
config_file="$xui_home/config.json"

function show_menu() {
    echo -e "${green}x-ui Management Menu${plain}"
    echo -e "1. Change panel port"
    echo -e "2. Reset panel settings"
    echo -e "3. Show current configuration"
    echo -e "4. Restart service"
    echo -e "5. Stop service"
    echo -e "6. Uninstall x-ui"
    echo -e "0. Exit"
    echo -n "Please enter your choice [0-6]: "
}

function start_service() {
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

function stop_service() {
    if [ -f $pid_file ]; then
        echo -e "${yellow}Stopping x-ui...${plain}"
        kill -9 $(cat $pid_file) 2>/dev/null
        rm -f $pid_file
        echo -e "${green}Service stopped successfully!${plain}"
    else
        echo -e "${red}Service is not running${plain}"
    fi
}

function restart_service() {
    stop_service
    start_service
}

function change_port() {
    if [ ! -f $config_file ]; then
        echo -e "${red}Config file not found!${plain}"
        return 1
    fi
    
    echo -e "${yellow}Current panel port: $(jq -r '.web.port' $config_file)${plain}"
    read -p "Enter new panel port (default: 2053): " new_port
    new_port=${new_port:-2053}
    
    # 验证端口
    if ! [[ $new_port =~ ^[0-9]+$ ]] || [ $new_port -lt 1 ] || [ $new_port -gt 65535 ]; then
        echo -e "${red}Invalid port number!${plain}"
        return 1
    fi
    
    # 修改配置
    jq ".web.port = $new_port" $config_file > $config_file.tmp && mv $config_file.tmp $config_file
    echo -e "${green}Port changed to $new_port${plain}"
    
    # 重启服务
    restart_service
}

function reset_panel() {
    echo -e "${yellow}Resetting panel settings...${plain}"
    stop_service
    
    local admin_user=$(gen_random_str 8)
    local admin_pass=$(gen_random_str 12)
    local panel_port=$(shuf -i 20000-65000 -n 1)
    local web_path=$(gen_random_str 10)
    
    cat > $config_file <<EOF
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
    
    start_service
}

function show_config() {
    if [ ! -f $config_file ]; then
        echo -e "${red}Config file not found!${plain}"
        return 1
    fi
    
    echo -e "${green}====== Current x-ui Configuration ======${plain}"
    echo -e "Panel Port: $(jq -r '.web.port' $config_file)"
    echo -e "Username: $(jq -r '.web.username' $config_file)"
    echo -e "Password: $(jq -r '.web.password' $config_file)"
    echo -e "Base Path: $(jq -r '.web.basePath' $config_file)"
    echo -e "PID File: $pid_file"
    echo -e "Log File: $log_file"
    echo -e "Binary Path: $xui_bin"
    echo -e "Config Path: $config_file"
    echo -e "${green}=======================================${plain}"
}

function uninstall_service() {
    echo -e "${yellow}Uninstalling x-ui...${plain}"
    stop_service
    
    rm -rf $xui_home
    rm -f $pid_file
    rm -f $log_file
    rm -f /usr/local/bin/x-ui
    
    echo -e "${green}x-ui has been uninstalled successfully!${plain}"
}

function gen_random_str() {
    head -c 100 /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $1 | head -n 1
}

while true; do
    show_menu
    read -r choice
    case $choice in
        1) change_port ;;
        2) reset_panel ;;
        3) show_config ;;
        4) restart_service ;;
        5) stop_service ;;
        6) uninstall_service ;;
        0) exit 0 ;;
        *) echo -e "${red}Invalid option!${plain}" ;;
    esac
    echo
done
EOF

    chmod +x /usr/local/bin/x-ui
    echo -e "${green}Management script installed to /usr/local/bin/x-ui${plain}"
}

# 主安装流程
main_install() {
    echo -e "${green}Starting x-ui installation...${plain}"
    check_os
    check_arch
    install_deps
    init_config
    install_core
    start_service
    
    echo -e "${green}========================================"
    echo -e " x-ui installation completed!"
    echo -e " Management command: x-ui"
    echo -e "========================================${plain}"
}

# 执行安装
main_install

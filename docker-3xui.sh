#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi

echo "The OS release is: $release"

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}Unsupported CPU architecture! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "Arch: $(arch)"

check_glibc_version() {
    glibc_version=$(ldd --version | head -n1 | awk '{print $NF}')
    required_version="2.32"
    if [[ "$(printf '%s\n' "$required_version" "$glibc_version" | sort -V | head -n1)" != "$required_version" ]]; then
        echo -e "${red}GLIBC version $glibc_version is too old! Required: 2.32 or higher${plain}"
        echo "Please upgrade to a newer version of your operating system to get a higher GLIBC version."
        exit 1
    fi
    echo "GLIBC version: $glibc_version (meets requirement of 2.32+)"
}

check_glibc_version

install_base() {
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    centos | almalinux | rocky | ol)
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora | amzn | virtuozzo)
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone
        ;;
    *)
        apt-get update && apt install -y -q wget curl tar tzdata
        ;;
    esac
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

config_after_install() {
    local existing_username=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'username: .+' | awk '{print $2}')
    local existing_password=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'password: .+' | awk '{print $2}')
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')
    local existing_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    local server_ip=$(curl -s https://api.ipify.org)

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_webBasePath=$(gen_random_string 15)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)
            read -rp "Would you like to customize the Panel Port settings? (If not, a random port will be applied) [y/n]: " config_confirm
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                read -rp "Please set up the panel port: " config_port
                echo -e "${yellow}Your Panel Port is: ${config_port}${plain}"
            else
                local config_port=$(shuf -i 1024-62000 -n 1)
                echo -e "${yellow}Generated random port: ${config_port}${plain}"
            fi
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            echo -e "${green}Configuration updated successfully!${plain}"
            echo -e "${blue}==================================================${plain}"
            echo -e "${blue}Panel Access Information${plain}"
            echo -e "${blue}==================================================${plain}"
            echo -e "${blue}Panel URL: http://${server_ip}:${config_port}/${config_webBasePath}${plain}"
            echo -e "${blue}Username: ${config_username}${plain}"
            echo -e "${blue}Password: ${config_password}${plain}"
            echo -e "${blue}==================================================${plain}"
        fi
    else
        echo -e "${green}Existing configuration detected and preserved.${plain}"
        echo -e "${blue}==================================================${plain}"
        echo -e "${blue}Panel Access Information${plain}"
        echo -e "${blue}==================================================${plain}"
        echo -e "${blue}Panel URL: http://${server_ip}:${existing_port}/${existing_webBasePath}${plain}"
        echo -e "${blue}Username: ${existing_username}${plain}"
        echo -e "${blue}Password: ${existing_password}${plain}"
        echo -e "${blue}==================================================${plain}"
    fi
}

# 添加非systemd的启动管理功能
add_to_startup() {
    echo -e "${green}Adding x-ui to startup without systemd...${plain}"
    
    # 创建启动脚本
    cat > /etc/init.d/x-ui <<EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:          x-ui
# Required-Start:    \$network \$local_fs \$remote_fs
# Required-Stop:     \$network \$local_fs \$remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: x-ui service
# Description:       x-ui service
### END INIT INFO

case "\$1" in
    start)
        echo "Starting x-ui..."
        nohup /usr/local/x-ui/x-ui >/dev/null 2>&1 &
        ;;
    stop)
        echo "Stopping x-ui..."
        killall x-ui
        ;;
    restart)
        echo "Restarting x-ui..."
        killall x-ui
        nohup /usr/local/x-ui/x-ui >/dev/null 2>&1 &
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
EOF

    # 设置权限
    chmod +x /etc/init.d/x-ui
    
    # 添加到启动项
    if command -v update-rc.d >/dev/null 2>&1; then
        update-rc.d x-ui defaults
    elif command -v chkconfig >/dev/null 2>&1; then
        chkconfig --add x-ui
        chkconfig x-ui on
    fi
    
    echo -e "${green}x-ui has been added to startup successfully!${plain}"
}

install_xui() {
    echo -e "${green}Installing x-ui...${plain}"
    
    # 下载并安装x-ui
    mkdir -p /usr/local/x-ui
    cd /usr/local/x-ui || exit 1
    
    # 根据架构下载合适的版本
    case $(arch) in
        amd64)
            wget -O x-ui.tar.gz https://github.com/vaxilu/x-ui/releases/latest/download/x-ui-linux-amd64.tar.gz
            ;;
        arm64)
            wget -O x-ui.tar.gz https://github.com/vaxilu/x-ui/releases/latest/download/x-ui-linux-arm64.tar.gz
            ;;
        armv7)
            wget -O x-ui.tar.gz https://github.com/vaxilu/x-ui/releases/latest/download/x-ui-linux-armv7.tar.gz
            ;;
        *)
            echo -e "${red}Unsupported architecture for x-ui!${plain}"
            exit 1
            ;;
    esac
    
    tar -zxvf x-ui.tar.gz
    rm -f x-ui.tar.gz
    
    # 设置可执行权限
    chmod +x x-ui
    
    # 添加到启动项
    add_to_startup
    
    # 启动服务
    /etc/init.d/x-ui start
    
    # 配置
    config_after_install
    
    echo -e "${green}x-ui installation completed!${plain}"
}

# 主安装流程
install_base
install_xui

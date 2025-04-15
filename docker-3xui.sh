#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# 检查root权限（保留不变）
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} 请使用root权限运行脚本\n" && exit 1

# 操作系统检测（保留不变）
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "无法检测操作系统，请联系作者！" >&2
    exit 1
fi

echo "系统版本: $release"

# CPU架构检测（保留不变）
arch() {
    case "$(uname -m)" in
        x86_64|x64|amd64) echo 'amd64' ;;
        i*86|x86) echo '386' ;;
        armv8*|armv8|arm64|aarch64) echo 'arm64' ;;
        armv7*|armv7|arm) echo 'armv7' ;;
        armv6*|armv6) echo 'armv6' ;;
        armv5*|armv5) echo 'armv5' ;;
        s390x) echo 's390x' ;;
        *) echo -e "${green}不支持的CPU架构! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "系统架构: $(arch)"

# GLIBC版本检查（保留不变）
check_glibc_version() {
    glibc_version=$(ldd --version | head -n1 | awk '{print $NF}')
    required_version="2.32"
    if [[ "$(printf '%s\n' "$required_version" "$glibc_version" | sort -V | head -n1)" != "$required_version" ]]; then
        echo -e "${red}GLIBC版本 $glibc_version 过低! 需要2.32或更高版本${plain}"
        echo "请升级系统以获取更高GLIBC版本。"
        exit 1
    fi
    echo "GLIBC版本: $glibc_version (满足2.32+要求)"
}

check_glibc_version

# 安装基础依赖（保留Debian系安装逻辑）
install_base() {
    case "${release}" in
        ubuntu|debian|armbian)
            apt-get update && apt-get install -y -q wget curl tar tzdata
            ;;
        # 其他系统保留但不会在Debian中使用
        *) 
            echo "非Debian系系统，可能不兼容"
            exit 1
            ;;
    esac
}

# 生成随机字符串（保留不变）
gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

# 创建SysVinit启动脚本
create_initd_script() {
    cat > /etc/init.d/x-ui <<EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:          x-ui
# Required-Start:    \$network \$local_fs \$remote_fs
# Required-Stop:     \$network \$local_fs \$remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: x-ui service
### END INIT INFO

case "\$1" in
    start)
        /usr/local/x-ui/x-ui start
        ;;
    stop)
        /usr/local/x-ui/x-ui stop
        ;;
    restart)
        /usr/local/x-ui/x-ui restart
        ;;
    status)
        /usr/local/x-ui/x-ui status
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF

    chmod +x /etc/init.d/x-ui
    update-rc.d x-ui defaults
}

# 安装后配置（保留自定义端口功能）
config_after_install() {
    # 原有配置读取逻辑保留
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
            
            # 保留自定义端口功能
            read -rp "是否自定义控制面板端口？(否则将使用随机端口) [y/n]: " config_confirm
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                read -rp "请输入端口号: " config_port
                echo -e "${yellow}控制面板端口: ${config_port}${plain}"
            else
                local config_port=$(shuf -i 1024-62000 -n 1)
                echo -e "${yellow}生成随机端口: ${config_port}${plain}"
            fi
            
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            echo -e "这是全新安装的x-ui面板"
            echo -e "面板地址: http://${server_ip}:${config_port}/${config_webBasePath}"
            echo -e "用户名: ${config_username}"
            echo -e "密码: ${config_password}"
        else
            echo -e "${green}检测到现有配置，保留原有设置${plain}"
        fi
    fi
}

# 主安装流程
install() {
    install_base
    
    # 下载x-ui（保留原有逻辑）
    local arch_type=$(arch)
    echo "正在下载x-ui..."
    mkdir -p /usr/local/x-ui
    wget -O /usr/local/x-ui/x-ui-linux-${arch_type}.tar.gz https://github.com/sing-web/x-ui/releases/latest/download/x-ui-linux-${arch_type}.tar.gz
    tar zxvf /usr/local/x-ui/x-ui-linux-${arch_type}.tar.gz -C /usr/local/x-ui
    rm -f /usr/local/x-ui/x-ui-linux-${arch_type}.tar.gz
    chmod +x /usr/local/x-ui/x-ui

    # 创建SysVinit脚本代替systemd
    create_initd_script
    
    # 启动服务
    echo -e "${green}正在启动x-ui服务...${plain}"
    /etc/init.d/x-ui start
    
    config_after_install
    
    echo -e "${green}x-ui安装完成！${plain}"
    echo -e "使用以下命令管理服务："
    echo -e "启动服务: ${yellow}/etc/init.d/x-ui start${plain}"
    echo -e "停止服务: ${yellow}/etc/init.d/x-ui stop${plain}"
    echo -e "重启服务: ${yellow}/etc/init.d/x-ui restart${plain}"
}

install

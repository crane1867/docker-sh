#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)
xui_bin_path="/usr/local/bin/x-ui"
xui_install_dir="/usr/local/x-ui"

# 检查root权限
[[ $EUID -ne 0 ]] && echo -e "${red}错误：请使用root权限运行脚本${plain}" && exit 1

# 操作系统检测
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "无法检测操作系统" >&2
    exit 1
fi

# 架构检测
arch() {
    case "$(uname -m)" in
        x86_64|x64|amd64) echo 'amd64' ;;
        i*86|x86) echo '386' ;;
        armv8*|armv8|arm64|aarch64) echo 'arm64' ;;
        armv7*|armv7|arm) echo 'armv7' ;;
        armv6*|armv6) echo 'armv6' ;;
        armv5*|armv5) echo 'armv5' ;;
        s390x) echo 's390x' ;;
        *) echo -e "${red}不支持的CPU架构! ${plain}" && exit 1 ;;
    esac
}

# GLIBC版本检查
check_glibc_version() {
    glibc_version=$(ldd --version | head -n1 | awk '{print $NF}')
    required_version="2.32"
    if [[ "$(printf '%s\n' "$required_version" "$glibc_version" | sort -V | head -n1)" != "$required_version" ]]; then
        echo -e "${red}GLIBC版本过低! 需要2.32+${plain}"
        exit 1
    fi
}

# 生成随机字符串
gen_random_string() {
    tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$1" | head -n 1
}

# 服务管理
service_manager() {
    case "$1" in
        start) /etc/init.d/x-ui start ;;
        stop) /etc/init.d/x-ui stop ;;
        restart) /etc/init.d/x-ui restart ;;
        status) /etc/init.d/x-ui status ;;
    esac
}

# 创建初始化脚本
create_initd_script() {
    cat > /etc/init.d/x-ui <<EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:          x-ui
# Required-Start:    \$network \$local_fs \$remote_fs
# Required-Stop:     \$network \$local_fs \$remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
### END INIT INFO

case "\$1" in
    start)
        ${xui_install_dir}/x-ui start
        ;;
    stop)
        ${xui_install_dir}/x-ui stop
        ;;
    restart)
        ${xui_install_dir}/x-ui restart
        ;;
    status)
        ${xui_install_dir}/x-ui status
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
    chmod +x /etc/init.d/x-ui
    update-rc.d x-ui defaults >/dev/null 2>&1
}

# 配置显示
show_config() {
    local config=$(${xui_install_dir}/x-ui setting -show true)
    echo -e "${green}当前配置：${plain}"
    echo -e "面板端口: $(echo "$config" | awk '/port:/ {print $2}')"
    echo -e "用户名: $(echo "$config" | awk '/username:/ {print $2}')"
    echo -e "密码: $(echo "$config" | awk '/password:/ {print $2}')"
    echo -e "访问路径: $(echo "$config" | awk '/webBasePath:/ {print $2}')"
}

# 修改端口
change_port() {
    read -p "请输入新端口号: " new_port
    ${xui_install_dir}/x-ui setting -port $new_port
    service_manager restart
    echo -e "${green}端口已修改为 $new_port${plain}"
}

# 重置配置
reset_config() {
    ${xui_install_dir}/x-ui setting -username "$(gen_random_string 10)" \
    -password "$(gen_random_string 15)" \
    -port "$(shuf -i 1024-62000 -n 1)" \
    -webBasePath "$(gen_random_string 8)"
    service_manager restart
    show_config
}

# 卸载功能
uninstall() {
    echo -e "${yellow}开始卸载x-ui...${plain}"
    service_manager stop
    rm -rf ${xui_install_dir}
    rm -f /etc/init.d/x-ui
    update-rc.d -f x-ui remove >/dev/null 2>&1
    rm -f ${xui_bin_path}
    echo -e "${green}x-ui 已卸载${plain}"
}

# 安装主逻辑
install_xui() {
    check_glibc_version
    arch_type=$(arch)
    
    echo -e "${yellow}安装依赖...${plain}"
    apt-get update && apt-get install -y wget curl tar
    
    echo -e "${yellow}下载x-ui...${plain}"
    wget -O ${xui_install_dir}/x-ui-linux-${arch_type}.tar.gz \
    https://github.com/sing-web/x-ui/releases/latest/download/x-ui-linux-${arch_type}.tar.gz
    tar zxvf ${xui_install_dir}/x-ui-linux-${arch_type}.tar.gz -C ${xui_install_dir}
    rm -f ${xui_install_dir}/x-ui-linux-${arch_type}.tar.gz
    chmod +x ${xui_install_dir}/x-ui
    
    create_initd_script
    service_manager start
    
    # 初始化配置
    if [ ! -f ${xui_install_dir}/db/x-ui.db ]; then
        reset_config
    fi
    
    # 创建快捷命令
    cat > ${xui_bin_path} <<EOF
#!/bin/bash
case "\$1" in
    1|reinstall) 
        ${xui_install_dir}/x-ui stop
        ${xui_install_dir}/x-ui install
        ${xui_install_dir}/x-ui start ;;
    2|uninstall) 
        $(declare -f uninstall)
        uninstall ;;
    3|change-port)
        $(declare -f change_port service_manager)
        change_port ;;
    4|reset-config)
        $(declare -f reset_config gen_random_string)
        reset_config ;;
    5|show-config)
        show_config ;;
    6|restart)
        service_manager restart ;;
    7|stop)
        service_manager stop ;;
    *)
        echo -e "快捷命令选项:"
        echo -e "1. 重新安装\t2. 卸载"
        echo -e "3. 修改端口\t4. 重置配置"
        echo -e "5. 查看配置\t6. 重启服务"
        echo -e "7. 停止服务" ;;
esac
EOF
    chmod +x ${xui_bin_path}
    
    echo -e "\n${green}安装完成！使用以下命令管理：${plain}"
    echo -e "查看配置: ${yellow}x-ui 5${plain}"
    echo -e "重启服务: ${yellow}x-ui 6${plain}"
    echo -e "修改端口: ${yellow}x-ui 3${plain}"
}

# 主入口
if [[ $0 == "$BASH_SOURCE" ]]; then
    case "$1" in
        install)
            install_xui
            ;;
        *)
            echo -e "用法: $0 install"
            exit 1
            ;;
    esac
fi

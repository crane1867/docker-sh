#!/bin/bash
# Caddy一键安装管理脚本
# 执行方式：bash <(curl -sL https://your-domain.com/caddy-manager.sh)

CADDY_VERSION="2.7.6"
CADDY_BIN="/usr/local/bin/caddy"
CONFIG_DIR="/etc/caddy"
LOG_DIR="/var/log/caddy"
SERVICE_FILE="/etc/init.d/caddy"

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "请使用root权限运行此脚本！"
        exit 1
    fi
}

# 安装依赖
install_deps() {
    apt-get update -qq
    apt-get install -y -qq curl tar
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list    
}

# 安装Caddy
install_caddy() {
    if [ ! -f "$CADDY_BIN" ]; then
        echo "正在下载Caddy v${CADDY_VERSION}..."
        curl -sL "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz" | \
        tar -C /usr/local/bin -xz caddy
        chmod +x "$CADDY_BIN"
    fi
}

# 配置Caddy
setup_caddy() {
    # 创建配置目录
    mkdir -p "$CONFIG_DIR" "$LOG_DIR"
    chown -R www-data:www-data "$CONFIG_DIR" "$LOG_DIR"
    
    # 生成默认Caddyfile
    if [ ! -f "${CONFIG_DIR}/Caddyfile" ]; then
        cat > "${CONFIG_DIR}/Caddyfile" <<EOF
{
    admin localhost:2019
    log {
        output file ${LOG_DIR}/access.log
    }
}

:80 {
    respond "Caddy 安装成功！"
}
EOF
    fi
}

# 安装服务脚本
install_service() {
    cat > "$SERVICE_FILE" <<'EOF'
#!/bin/sh
# Caddy 服务管理脚本

DAEMON="/usr/local/bin/caddy"
CONFIG="/etc/caddy/Caddyfile"
USER="www-data"
GROUP="www-data"
PID_FILE="/var/run/caddy.pid"
LOG_FILE="/var/log/caddy/error.log"

case "$1" in
    start)
        echo "启动Caddy..."
        start-stop-daemon --start --quiet --background \
            --pidfile "$PID_FILE" \
            --make-pidfile \
            --chuid "$USER:$GROUP" \
            --exec "$DAEMON" -- run --config "$CONFIG" --adapter caddyfile
        ;;
    stop)
        echo "停止Caddy..."
        start-stop-daemon --stop --quiet --pidfile "$PID_FILE"
        rm -f "$PID_FILE"
        ;;
    reload)
        echo "重载配置..."
        curl -s http://localhost:2019/load \
            -X POST \
            -H "Content-Type: text/caddyfile" \
            --data-binary @"$CONFIG"
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") >/dev/null 2>&1; then
            echo "Caddy正在运行 (PID: $(cat "$PID_FILE"))"
        else
            echo "Caddy未运行"
            exit 3
        fi
        ;;
    *)
        echo "使用方法: $0 {start|stop|restart|reload|status}"
        exit 1
        ;;
esac
EOF

    chmod +x "$SERVICE_FILE"
    update-rc.d caddy defaults >/dev/null 2>&1
}

# 创建管理命令
create_alias() {
    cat > /usr/local/bin/caddy <<'EOF'
#!/bin/bash

show_menu() {
    clear
    echo -e "\n\033[34mCaddy 管理菜单\033[0m"
    echo "1. 启动Caddy"
    echo "2. 停止Caddy"
    echo "3. 重启Caddy"
    echo "4. 重载配置"
    echo "5. 查看状态"
    echo "6. 查看日志"
    echo "7. 编辑配置"
    echo "8. 退出"
}

while true; do
    show_menu
    read -p "请输入选项 [1-8]: " choice
    case $choice in
        1) service caddy start ;;
        2) service caddy stop ;;
        3) service caddy restart ;;
        4) service caddy reload ;;
        5) service caddy status ;;
        6) tail -f /var/log/caddy/access.log ;;
        7) nano /etc/caddy/Caddyfile ;;
        8) exit 0 ;;
        *) echo "无效选项，请重新输入！" ;;
    esac
    read -n 1 -s -r -p "按任意键继续..."
done
EOF

    chmod +x /usr/local/bin/caddy
}

main() {
    check_root
    echo -e "\n\033[32m[1/5] 安装依赖...\033[0m"
    install_deps
    
    echo -e "\n\033[32m[2/5] 安装Caddy...\033[0m"
    install_caddy
    
    echo -e "\n\033[32m[3/5] 配置环境...\033[0m"
    setup_caddy
    
    echo -e "\n\033[32m[4/5] 安装服务...\033[0m"
    install_service
    
    echo -e "\n\033[32m[5/5] 创建管理菜单...\033[0m"
    create_alias
    
    echo -e "\n\033[32m安装完成！\033[0m"
    echo -e "使用命令 \033[33mcaddy\033[0m 打开管理菜单"
    echo -e "直接管理命令: service caddy {start|stop|restart|reload|status}\n"
}

main

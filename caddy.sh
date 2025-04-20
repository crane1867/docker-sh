#!/bin/bash
# Caddy 无 systemd 安装与管理脚本

CADDY_VERSION="2.7.6"
CADDY_BIN="/usr/local/bin/caddy"
CONFIG_DIR="/etc/caddy"
LOG_DIR="/var/log/caddy"
PID_FILE="/var/run/caddy.pid"
MANAGER_SCRIPT="/usr/local/bin/caddy-manager"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "请使用root权限运行此脚本！"
        exit 1
    fi
}

install_deps() {
    echo "[+] 安装必要依赖..."
    apt-get update -qq
    apt-get install -y curl tar
}

install_caddy() {
    if [ ! -f "$CADDY_BIN" ]; then
        echo "[+] 下载并安装 Caddy v${CADDY_VERSION}..."
        curl -sL "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz" | \
        tar -C /usr/local/bin -xz caddy
        chmod +x "$CADDY_BIN"
    else
        echo "[*] Caddy 已存在，跳过安装"
    fi
}

setup_environment() {
    echo "[+] 创建配置与日志目录..."
    mkdir -p "$CONFIG_DIR" "$LOG_DIR"
    touch "${LOG_DIR}/access.log" "${LOG_DIR}/error.log"
    chown -R www-data:www-data "$CONFIG_DIR" "$LOG_DIR"
    chmod 664 "${LOG_DIR}"/*.log

    if [ ! -f "${CONFIG_DIR}/Caddyfile" ]; then
        cat > "${CONFIG_DIR}/Caddyfile" <<EOF
{
    admin 127.0.0.1:2019
    log {
        output file /var/log/caddy/access.log {
            roll_size 100mb
            roll_keep 5
        }
        level ERROR
    }
    http_port 8080
    https_port 8443
}


:80 {
    respond "Caddy 安装成功！"
}
EOF
        echo "[+] 默认Caddyfile已生成！"
    fi
}

install_manager() {
    echo "[+] 安装无systemd管理脚本..."
    cat > "$MANAGER_SCRIPT" <<EOF
#!/bin/bash
CADDY_BIN="$CADDY_BIN"
CONFIG="$CONFIG_DIR/Caddyfile"
LOG_FILE="$LOG_DIR/error.log"
PID_FILE="$PID_FILE"

start() {
    if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
        echo "Caddy 已经在运行 (PID: \$(cat \$PID_FILE))"
    else
        echo "正在启动 Caddy..."
        nohup "\$CADDY_BIN" run --config "\$CONFIG" --adapter caddyfile >> "\$LOG_FILE" 2>&1 &
        echo \$! > "\$PID_FILE"
        echo "Caddy 启动完成，PID: \$(cat \$PID_FILE)"
    fi
}

stop() {
    if [ -f "\$PID_FILE" ]; then
        PID=\$(cat "\$PID_FILE")
        if kill -0 "\$PID" 2>/dev/null; then
            kill "\$PID"
            rm -f "\$PID_FILE"
            echo "Caddy 已停止"
        else
            echo "进程不存在，清理 PID 文件"
            rm -f "\$PID_FILE"
        fi
    else
        echo "Caddy 未在运行"
    fi
}

reload() {
    echo "尝试重载配置..."
    curl -s http://localhost:2019/load -X POST -H "Content-Type: text/caddyfile" --data-binary @"\$CONFIG"
    echo -e "\\n配置已重载。"
}

status() {
    if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
        echo "Caddy 正在运行 (PID: \$(cat \$PID_FILE))"
    else
        echo "Caddy 未运行"
    fi
}

restart() {
    stop
    sleep 1
    start
}

enable_autostart() {
    if grep -q "\$MANAGER_SCRIPT start" /etc/rc.local 2>/dev/null; then
        echo "已设置开机自启"
    else
        sed -i '/^exit 0/i\$MANAGER_SCRIPT start' /etc/rc.local
        chmod +x /etc/rc.local
        echo "已设置 /etc/rc.local 开机自启"
    fi
}

uninstall() {
    stop
    rm -f "\$CADDY_BIN" "\$PID_FILE"
    rm -rf "$CONFIG_DIR" "$LOG_DIR"
    sed -i "\|$MANAGER_SCRIPT start|d" /etc/rc.local
    rm -f "$MANAGER_SCRIPT"
    echo "Caddy 已卸载完成"
}

case "\$1" in
    start) start ;;
    stop) stop ;;
    reload) reload ;;
    restart) restart ;;
    status) status ;;
    enable-autostart) enable_autostart ;;
    uninstall) uninstall ;;
    *)
        echo "用法: \$0 {start|stop|restart|reload|status|enable-autostart|uninstall}"
        exit 1
        ;;
esac
EOF

    chmod +x "$MANAGER_SCRIPT"
}

main() {
    check_root
    install_deps
    install_caddy
    setup_environment
    install_manager
    echo -e "\\n✅ Caddy 安装完成！"
    echo -e "👉 使用命令： \033[33mcaddy-manager {start|stop|restart|reload|status|enable-autostart|uninstall}\033[0m"
}

main

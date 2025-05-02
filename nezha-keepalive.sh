#!/bin/bash
# 一键保活部署脚本 - 适用于无 systemd 的 Debian 系统

set -e  # 遇到错误自动退出

# 检查 root 权限
if [ "$(id -u)" != "0" ]; then
    echo "错误：请使用 root 权限运行此脚本 (sudo $0)" >&2
    exit 1
fi

# 安装依赖
echo "正在安装编译依赖..."
apt update >/dev/null 2>&1
if ! command -v gcc >/dev/null 2>&1; then
    apt install -y gcc >/dev/null 2>&1 || {
        echo "无法安装 gcc，请手动执行: apt update && apt install -y gcc" >&2
        exit 1
    }
fi

# 创建 syslog 劫持库
echo "正在配置 syslog 劫持..."
mkdir -p /opt/nezha/agent
cat > /opt/nezha/agent/fake_syslog.c <<'EOF'
#include <stdarg.h>
#include <syslog.h>

void syslog(int priority, const char *format, ...) {}
void closelog(void) {}
void openlog(const char *ident, int option, int facility) {}
EOF

gcc -shared -fPIC -o /opt/nezha/agent/libfake_syslog.so /opt/nezha/agent/fake_syslog.c >/dev/null 2>&1 || {
    echo "编译劫持库失败，请检查 gcc 是否安装" >&2
    exit 1
}

# 创建保活脚本
echo "正在部署保活服务..."
cat > /opt/nezha/agent/keepalive.sh <<'EOF'
#!/bin/bash
export LD_PRELOAD="/opt/nezha/agent/libfake_syslog.so"
LOG_DIR="/opt/nezha/agent/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/nezha-agent.log"

if ! pgrep -f "nezha-agent -c /opt/nezha/agent/config.yml" >/dev/null; then
    nohup /opt/nezha/agent/nezha-agent -c /opt/nezha/agent/config.yml >>"$LOG_FILE" 2>&1 &
fi
EOF

chmod +x /opt/nezha/agent/keepalive.sh

# 配置定时任务
echo "正在设置定时任务..."
(crontab -l 2>/dev/null | grep -v "/opt/nezha/agent/keepalive.sh"; echo "* * * * * /opt/nezha/agent/keepalive.sh") | crontab -

# 首次启动
echo "启动服务中..."
/opt/nezha/agent/keepalive.sh

# 验证结果
echo -e "\n\033[32m部署完成！验证结果：\033[0m"
sleep 2
echo -e "进程状态：\033[33m$(pgrep -f nezha-agent || echo "未运行")\033[0m"
echo -e "定时任务：\033[33m"
crontab -l | grep nezha-agent
echo -e "\033[0m最新日志："
tail -n 4 /opt/nezha/agent/logs/nezha-agent.log 2>/dev/null || echo "暂无日志"

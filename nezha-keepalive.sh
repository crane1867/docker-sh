#!/bin/bash
# 一键保活脚本 - 仅依赖 cron

set -e  # 遇错自动退出

# 检查 root 权限
if [ "$(id -u)" != "0" ]; then
    echo "错误：请使用 root 权限运行 (sudo $0)" >&2
    exit 1
fi

# 安装 cron 服务（如果未安装）
if ! command -v cron >/dev/null 2>&1; then
    echo "正在安装 cron 服务..."
    apt update >/dev/null 2>&1
    apt install -y cron >/dev/null 2>&1 || {
        echo "无法安装 cron，请手动执行: apt update && apt install -y cron" >&2
        exit 1
    }
fi

# 创建保活脚本
echo "正在创建保活脚本..."
tee /opt/nezha/agent/keepalive.sh <<'EOF'
#!/bin/bash
LOG_DIR="/opt/nezha/agent/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/nezha-agent.log"

# 如果进程不存在则启动（直接重定向输出到文件）
if ! pgrep -f "nezha-agent -c /opt/nezha/agent/config.yml" >/dev/null; then
    nohup /opt/nezha/agent/nezha-agent -c /opt/nezha/agent/config.yml >"$LOG_FILE" 2>&1 &
fi

EOF

# 首次启动
echo "启动服务中..."
chmod +x /opt/nezha/agent/keepalive.sh
/opt/nezha/agent/keepalive.sh
service cron start

# 配置定时任务
echo "正在设置定时任务..."

(crontab -l 2>/dev/null; echo "* * * * * /opt/nezha/agent/keepalive.sh") | crontab -

# 验证结果
echo -e "\n\033[32m[部署结果]\033[0m"
echo -e "进程 PID: \033[33m$(pgrep -f nezha-agent || echo "未运行")\033[0m"
echo -e "定时任务状态: \033[33m$(crontab -l | grep -F "/opt/nezha/agent/keepalive.sh" || echo "未检测到")\033[0m"

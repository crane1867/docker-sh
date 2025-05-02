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
    systemctl enable cron >/dev/null 2>&1 || service cron start >/dev/null 2>&1
fi

# 创建保活脚本
echo "正在创建保活脚本..."
mkdir -p /opt/nezha/agent/logs
cat > /opt/nezha/agent/keepalive.sh <<'EOF'
#!/bin/bash
LOG_FILE="/opt/nezha/agent/logs/nezha-agent.log"

# 检查进程是否存在
if ! pgrep -f "nezha-agent -c /opt/nezha/agent/config.yml" >/dev/null; then
    # 启动并丢弃所有输出（若需日志请将 >/dev/null 改为 >>"$LOG_FILE"）
    nohup /opt/nezha/agent/nezha-agent -c /opt/nezha/agent/config.yml >/dev/null 2>&1 &
fi
EOF

chmod +x /opt/nezha/agent/keepalive.sh

# 配置定时任务（防重复添加）
echo "正在设置定时任务..."
CRON_JOB="* * * * * /opt/nezha/agent/keepalive.sh"
(crontab -l 2>/dev/null | grep -v "/opt/nezha/agent/keepalive.sh"; echo "$CRON_JOB") | crontab -

# 首次启动
echo "启动服务中..."
/opt/nezha/agent/keepalive.sh

# 验证结果
echo -e "\n\033[32m[部署结果]\033[0m"
echo -e "进程 PID: \033[33m$(pgrep -f nezha-agent || echo "未运行")\033[0m"
echo -e "定时任务: \033[33m$(crontab -l | grep nezha-agent)\033[0m"

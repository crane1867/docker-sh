#!/bin/bash
# 不依赖systemd的Hysteria2一键脚本

# 定义颜色函数
random_color() {
  colors=("31" "32" "33" "34" "35" "36" "37")
  echo -e "\e[${colors[$((RANDOM % 7))]}m$1\e[0m"
}

# 检查root权限
if [ "$EUID" -ne 0 ]; then
  echo -e "$(random_color '请使用root用户执行！')"
  exit 1
fi

# 安装依赖
install_deps() {
  echo -e "$(random_color '正在安装依赖...')"
  if command -v apt &> /dev/null; then
    apt update
    apt install -y wget openssl jq
  elif command -v yum &> /dev/null; then
    yum install -y wget openssl jq
  else
    echo -e "$(random_color '不支持的包管理器！')"
    exit 1
  fi
}

# 安装Hysteria核心
install_core() {
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *) echo -e "$(random_color '不支持的架构！')"; exit 1 ;;
  esac

  LATEST_VER=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | jq -r .tag_name)
  DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/$LATEST_VER/hysteria-linux-$ARCH"

  mkdir -p /root/hy3
  cd /root/hy3
  
  echo -e "$(random_color '正在下载Hysteria...')"
  wget -q $DOWNLOAD_URL -O hysteria
  chmod +x hysteria
}

# 生成配置文件
gen_config() {
  echo -e "$(random_color '\n正在生成配置...')"
  read -p "请输入监听端口（默认443）: " PORT
  PORT=${PORT:-443}

  read -p "请输入密码（留空自动生成）: " PASS
  if [ -z "$PASS" ]; then
    PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
  fi

  read -p "请输入伪装域名（默认bing.com）: " DOMAIN
  DOMAIN=${DOMAIN:-bing.com}

  # 生成自签名证书
  mkdir -p /root/hy3/certs
  openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
    -keyout /root/hy3/certs/key.pem \
    -out /root/hy3/certs/cert.pem \
    -subj "/CN=$DOMAIN" -days 36500

  cat > /root/hy3/config.yaml <<EOF
listen: :$PORT
tls:
  cert: /root/hy3/certs/cert.pem
  key: /root/hy3/certs/key.pem
auth:
  type: password
  password: $PASS
masquerade:
  type: proxy
  proxy:
    url: https://$DOMAIN
    rewriteHost: true
EOF
}

# 启动服务
start_service() {
  echo -e "$(random_color '\n启动服务中...')"
  cd /root/hy3
  
  # 创建启动脚本
  cat > start.sh <<EOF
#!/bin/bash
while true; do
  ./hysteria server --config config.yaml
  sleep 10
done
EOF

  chmod +x start.sh
  nohup ./start.sh > hysteria.log 2>&1 &
  
  sleep 2
  if pgrep -f "hysteria server" >/dev/null; then
    echo -e "$(random_color '服务启动成功！')"
  else
    echo -e "$(random_color '服务启动失败，请检查日志！')"
    exit 1
  fi
}

# 显示配置
show_config() {
  IP=$(curl -s4m8 ip.sb -k) || IP=$(curl -s6m8 ip.sb -k)
  PORT=$(grep 'listen: ' /root/hy3/config.yaml | awk '{print $2}' | cut -d':' -f2)
  PASS=$(grep 'password: ' /root/hy3/config.yaml | awk '{print $2}')
  DOMAIN=$(grep 'url: ' /root/hy3/config.yaml | awk '{print $2}' | cut -d'/' -f3)

  echo -e "$(random_color '\n============ 配置信息 ============')"
  echo -e "$(random_color '服务器IP：')$IP"
  echo -e "$(random_color '端口：')$PORT"
  echo -e "$(random_color '密码：')$PASS"
  echo -e "$(random_color '伪装域名：')$DOMAIN"
  echo -e "$(random_color '协议：')hysteria2"
  echo -e "$(random_color 'SNI：')$DOMAIN"
  echo -e "$(random_color '跳过证书验证：')true"
  echo -e "$(random_color '===============================')"
  echo -e "$(random_color '客户端连接命令：')"
  echo -e "hysteria2://$PASS@$IP:$PORT/?insecure=1&sni=$DOMAIN#Docker_Hy2"
}

# 主流程
main() {
  install_deps
  install_core
  gen_config
  start_service
  show_config
}

main

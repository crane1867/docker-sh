#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

# 打印日志函数
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

# 检查 root 权限
[[ $EUID -ne 0 ]] && LOGE "ERROR: You must be root to run this script! \n" && exit 1

# 检查系统信息
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

os_version=$(grep "^VERSION_ID" /etc/os-release | cut -d '=' -f2 | tr -d '"' | tr -d '.')

# 定义日志相关目录变量
log_folder="${XUI_LOG_FOLDER:=/var/log}"
iplimit_log_path="${log_folder}/3xipl.log"
iplimit_banned_log_path="${log_folder}/3xipl-banned.log"

confirm() {
    if [[ $# -gt 1 ]]; then
        echo && read -rp "$1 [Default $2]: " temp
        [[ -z "$temp" ]] && temp=$2
    else
        read -rp "$1 [y/n]: " temp
    fi
    [[ "$temp" == "y" || "$temp" == "Y" ]]
}

confirm_restart() {
    confirm "Restart the panel, Attention: Restarting the panel will also restart xray" "y"
    if [[ $? -eq 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/main/install.sh)
    if [[ $? -eq 0 ]]; then
        if [[ $# -eq 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "This function will forcefully reinstall the latest version, and the data will not be lost. Do you want to continue?" "y"
    if [[ $? -ne 0 ]]; then
        LOGE "Cancelled"
        [[ $# -eq 0 ]] && before_show_menu
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/main/install.sh)
    if [[ $? -eq 0 ]]; then
        LOGI "Update is complete, Panel has automatically restarted"
        before_show_menu
    fi
}

update_menu() {
    echo -e "${yellow}Updating Menu${plain}"
    confirm "This function will update the menu to the latest changes." "y"
    if [[ $? -ne 0 ]]; then
        LOGE "Cancelled"
        [[ $# -eq 0 ]] && before_show_menu
        return 0
    fi

    wget -O /usr/bin/x-ui https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui

    if [[ $? -eq 0 ]]; then
        echo -e "${green}Update successful. The panel has automatically restarted.${plain}"
        exit 0
    else
        echo -e "${red}Failed to update the menu.${plain}"
        return 1
    fi
}

legacy_version() {
    echo "Enter the panel version (like 2.4.0):"
    read tag_version

    if [ -z "$tag_version" ]; then
        echo "Panel version cannot be empty. Exiting."
        exit 1
    fi
    install_command="bash <(curl -Ls \"https://raw.githubusercontent.com/mhsanaei/3x-ui/v$tag_version/install.sh\") v$tag_version"
    echo "Downloading and installing panel version $tag_version..."
    eval $install_command
}

delete_script() {
    rm "$0"
    exit 1
}

uninstall() {
    confirm "Are you sure you want to uninstall the panel? xray will also be uninstalled!" "n"
    if [[ $? -ne 0 ]]; then
        [[ $# -eq 0 ]] && show_menu
        return 0
    fi
    stop
    rm -rf /etc/x-ui/
    rm -rf /usr/local/x-ui/

    echo ""
    echo -e "Uninstalled Successfully.\n"
    echo "If you need to install this panel again, you can use below command:"
    echo -e "${green}bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)${plain}"
    trap delete_script SIGTERM
    delete_script
}

reset_user() {
    confirm "Are you sure to reset the username and password of the panel?" "n"
    if [[ $? -ne 0 ]]; then
        [[ $# -eq 0 ]] && show_menu
        return 0
    fi
    read -rp "Please set the login username [default is a random username]: " config_account
    [[ -z $config_account ]] && config_account=$(date +%s%N | md5sum | cut -c 1-8)
    read -rp "Please set the login password [default is a random password]: " config_password
    [[ -z $config_password ]] && config_password=$(date +%s%N | md5sum | cut -c 1-8)
    /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} >/dev/null 2>&1
    /usr/local/x-ui/x-ui setting -remove_secret >/dev/null 2>&1
    echo -e "Panel login username has been reset to: ${green}${config_account}${plain}"
    echo -e "Panel login password has been reset to: ${green}${config_password}${plain}"
    echo -e "${yellow}Panel login secret token disabled${plain}"
    echo -e "${green}Please use the new login username and password to access the X-UI panel. Also remember them!${plain}"
    confirm_restart
}

gen_random_string() {
    local length="$1"
    LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1
}

reset_webbasepath() {
    echo -e "${yellow}Resetting Web Base Path${plain}"
    read -rp "Are you sure you want to reset the web base path? (y/n): " confirm_ans
    [[ "$confirm_ans" != "y" && "$confirm_ans" != "Y" ]] && echo -e "${yellow}Operation canceled.${plain}" && return
    config_webBasePath=$(gen_random_string 10)
    /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}" >/dev/null 2>&1
    echo -e "Web base path has been reset to: ${green}${config_webBasePath}${plain}"
    restart
}

reset_config() {
    confirm "Are you sure you want to reset all panel settings, Account data will not be lost, Username and password will not change" "n"
    if [[ $? -ne 0 ]]; then
        [[ $# -eq 0 ]] && show_menu
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "All panel settings have been reset to default."
    restart
}

# ============================
# 以下为不依赖 systemd 的核心命令实现
# ============================

start() {
    if pgrep -f "/usr/local/x-ui/x-ui" > /dev/null; then
        echo ""
        LOGI "Panel is already running, no need to start again. For restart, please select restart."
    else
        nohup /usr/local/x-ui/x-ui > /dev/null 2>&1 &
        sleep 2
        if pgrep -f "/usr/local/x-ui/x-ui" > /dev/null; then
            LOGI "x-ui Started Successfully"
        else
            LOGE "Panel Failed to start, please check the log information later"
        fi
    fi
    [[ $# -eq 0 ]] && before_show_menu
}

stop() {
    if ! pgrep -f "/usr/local/x-ui/x-ui" > /dev/null; then
        echo ""
        LOGI "Panel is not running, no need to stop."
    else
        pkill -f "/usr/local/x-ui/x-ui"
        sleep 2
        if ! pgrep -f "/usr/local/x-ui/x-ui" > /dev/null; then
            LOGI "x-ui stopped successfully"
        else
            LOGE "Panel stop failed, please check the log information later"
        fi
    fi
    [[ $# -eq 0 ]] && before_show_menu
}

restart() {
    stop
    sleep 2
    start
    if pgrep -f "/usr/local/x-ui/x-ui" > /dev/null; then
        LOGI "x-ui Restarted successfully"
    else
        LOGE "Panel restart failed, please check the log information later"
    fi
    [[ $# -eq 0 ]] && before_show_menu
}

status() {
    if pgrep -f "/usr/local/x-ui/x-ui" > /dev/null; then
        LOGI "x-ui is running"
    else
        LOGI "x-ui is not running"
    fi
    [[ $# -eq 0 ]] && before_show_menu
}

enable() {
    LOGI "Autostart feature is not managed automatically in non-systemd mode."
    LOGI "Please add '/usr/local/x-ui/x-ui' to your startup scripts (e.g. /etc/rc.local) if needed."
    [[ $# -eq 0 ]] && before_show_menu
}

disable() {
    LOGI "Autostart feature is not managed automatically in non-systemd mode."
    [[ $# -eq 0 ]] && before_show_menu
}

# 修改 update_geo 中的 systemctl 调用为本地 start/stop 方式
update_geo() {
    echo -e "${green}\t1.${plain} Loyalsoldier (geoip.dat, geosite.dat)"
    echo -e "${green}\t2.${plain} chocolate4u (geoip_IR.dat, geosite_IR.dat)"
    echo -e "${green}\t3.${plain} runetfreedom (geoip_RU.dat, geosite_RU.dat)"
    echo -e "${green}\t0.${plain} Back to Main Menu"
    read -rp "Choose an option: " choice
    cd /usr/local/x-ui/bin
    case "$choice" in
    0)
        show_menu
        ;;
    1)
        stop
        rm -f geoip.dat geosite.dat
        wget -N https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
        wget -N https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
        echo -e "${green}Loyalsoldier datasets have been updated successfully!${plain}"
        restart
        ;;
    2)
        stop
        rm -f geoip_IR.dat geosite_IR.dat
        wget -O geoip_IR.dat -N https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geoip.dat
        wget -O geosite_IR.dat -N https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geosite.dat
        echo -e "${green}chocolate4u datasets have been updated successfully!${plain}"
        restart
        ;;
    3)
        stop
        rm -f geoip_RU.dat geosite_RU.dat
        wget -O geoip_RU.dat -N https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geoip.dat
        wget -O geosite_RU.dat -N https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geosite.dat
        echo -e "${green}runetfreedom datasets have been updated successfully!${plain}"
        restart
        ;;
    *)
        echo -e "${red}Invalid option. Please select a valid number.${plain}\n"
        update_geo
        ;;
    esac
    before_show_menu
}

# 修改 show_log，由于不使用 systemd，则显示 nohup.out 日志
show_log() {
    echo -e "${green}\t1.${plain} Show Log (tail -f nohup.out)"
    echo -e "${green}\t2.${plain} Clear nohup.out"
    echo -e "${green}\t0.${plain} Back to Main Menu"
    read -rp "Choose an option: " choice
    case "$choice" in
    0)
        show_menu
        ;;
    1)
        tail -f nohup.out
        [[ $# -eq 0 ]] && before_show_menu
        ;;
    2)
        > nohup.out
        echo "Log cleared."
        restart
        ;;
    *)
        echo -e "${red}Invalid option. Please select a valid number.${plain}\n"
        show_log
        ;;
    esac
}

# 其余部分（如 reset_config、firewall_menu、ssl_cert_issue*、iplimit_*、SSH_port_forwarding 等）保持原有逻辑，
# 如其中涉及 systemctl 调用的部分，根据实际情况可按上述思路进行修改，如有需要自行替换为对应的命令或提示信息。

# 此处省略其它辅助子函数的内容……
# 最后显示主菜单
show_usage() {
    echo -e "┌───────────────────────────────────────────────────────┐
│  ${blue}x-ui control menu usages (subcommands):${plain}              │
│                                                       │
│  ${blue}x-ui${plain}              - Admin Management Script          │
│  ${blue}x-ui start${plain}        - Start                            │
│  ${blue}x-ui stop${plain}         - Stop                             │
│  ${blue}x-ui restart${plain}      - Restart                          │
│  ${blue}x-ui status${plain}       - Current Status                   │
│  ${blue}x-ui settings${plain}     - Current Settings                 │
│  ${blue}x-ui enable${plain}       - Enable Autostart on OS Startup   │
│  ${blue}x-ui disable${plain}      - Disable Autostart on OS Startup  │
│  ${blue}x-ui log${plain}          - Check logs                       │
│  ${blue}x-ui banlog${plain}       - Check Fail2ban ban logs          │
│  ${blue}x-ui update${plain}       - Update                           │
│  ${blue}x-ui legacy${plain}       - Legacy version                   │
│  ${blue}x-ui install${plain}      - Install                          │
│  ${blue}x-ui uninstall${plain}    - Uninstall                        │
└───────────────────────────────────────────────────────┘"
}

# 根据传入的参数判断调用哪个子命令
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    settings)
        /usr/local/x-ui/x-ui setting -show true
        ;;
    enable)
        enable
        ;;
    disable)
        disable
        ;;
    log)
        show_log
        ;;
    banlog)
        # 保留原有 check ban log 部分（如有 systemd 调用，可酌情修改）
        # 此处暂直接调用原函数（未修改部分）
        show_banlog
        ;;
    update)
        update
        ;;
    legacy)
        legacy_version
        ;;
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    *)
        show_usage
        ;;
esac

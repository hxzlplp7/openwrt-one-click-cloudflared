#!/bin/sh

# =========================================
# Cloudflared 一键安装管理脚本
# 适用于 OpenWrt / iStoreOS
# 
# 使用远程管理隧道 (Token) 方式
# Token 需要在 Cloudflare Zero Trust 面板创建
# =========================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PLAIN='\033[0m'

# 路径定义
CLOUDFLARED_PATH="/usr/bin/cloudflared"
INIT_SCRIPT="/etc/init.d/cloudflared"
CONFIG_DIR="/etc/cloudflared"
TOKEN_FILE="${CONFIG_DIR}/token"

# 打印带颜色的消息
print_color() {
    printf "${1}${2}${PLAIN}\n"
}

print_info() {
    print_color "$BLUE" "$1"
}

print_success() {
    print_color "$GREEN" "$1"
}

print_warning() {
    print_color "$YELLOW" "$1"
}

print_error() {
    print_color "$RED" "$1"
}

print_cyan() {
    print_color "$CYAN" "$1"
}

# 检查 root 权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        print_error "错误: 此脚本必须以 root 身份运行!"
        exit 1
    fi
}

# 获取系统架构
get_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        aarch64)
            echo "arm64"
            ;;
        armv7l|armv7)
            echo "arm"
            ;;
        *)
            print_error "不支持的架构: $arch"
            return 1
            ;;
    esac
}

# 检查是否已安装
is_installed() {
    [ -f "$CLOUDFLARED_PATH" ] && [ -x "$CLOUDFLARED_PATH" ]
}

# 检查服务是否运行
is_running() {
    pgrep -f "$CLOUDFLARED_PATH" > /dev/null 2>&1
}

# 显示获取 Token 的说明
show_token_guide() {
    printf "\n"
    print_cyan "============================================"
    print_cyan "         如何获取 Cloudflare Tunnel Token"
    print_cyan "============================================"
    printf "\n"
    print_info "本脚本使用 Cloudflare 的「远程管理隧道」方式。"
    print_info "您需要先在 Cloudflare 面板创建隧道，然后获取 Token。"
    printf "\n"
    print_warning "步骤如下:"
    printf "\n"
    printf "  ${GREEN}1.${PLAIN} 打开 Cloudflare Zero Trust 面板:\n"
    printf "     ${CYAN}https://one.dash.cloudflare.com/${PLAIN}\n"
    printf "\n"
    printf "  ${GREEN}2.${PLAIN} 登录您的 Cloudflare 账户\n"
    printf "\n"
    printf "  ${GREEN}3.${PLAIN} 在左侧菜单找到 ${YELLOW}Networks${PLAIN} → ${YELLOW}Tunnels${PLAIN}\n"
    printf "\n"
    printf "  ${GREEN}4.${PLAIN} 点击 ${YELLOW}Create a tunnel${PLAIN} (创建隧道)\n"
    printf "\n"
    printf "  ${GREEN}5.${PLAIN} 选择 ${YELLOW}Cloudflared${PLAIN} 作为连接器类型\n"
    printf "\n"
    printf "  ${GREEN}6.${PLAIN} 给隧道起一个名字 (例如: openwrt-tunnel)\n"
    printf "\n"
    printf "  ${GREEN}7.${PLAIN} 在 \"Install and run a connector\" 页面，\n"
    printf "     找到类似这样的命令:\n"
    printf "     ${CYAN}cloudflared tunnel run --token eyJhIjoi...${PLAIN}\n"
    printf "\n"
    printf "  ${GREEN}8.${PLAIN} 复制 ${YELLOW}--token${PLAIN} 后面的那一长串字符\n"
    printf "     (以 eyJ 开头的 Base64 编码字符串)\n"
    printf "\n"
    printf "  ${GREEN}9.${PLAIN} 将 Token 粘贴到本脚本中\n"
    printf "\n"
    print_cyan "============================================"
    printf "\n"
}

# 安装 cloudflared
install_cloudflared() {
    if is_installed; then
        print_warning "cloudflared 已安装，当前版本:"
        $CLOUDFLARED_PATH --version
        printf "是否重新安装? [y/N]: "
        read -r confirm
        case "$confirm" in
            [yY][eE][sS]|[yY])
                ;;
            *)
                return
                ;;
        esac
    fi

    local arch
    arch=$(get_arch)
    if [ $? -ne 0 ]; then
        return 1
    fi

    print_info "正在更新软件包列表..."
    opkg update > /dev/null 2>&1

    print_info "正在安装依赖 (wget-ssl, ca-certificates)..."
    opkg install wget-ssl ca-certificates ca-bundle > /dev/null 2>&1

    print_info "正在下载 cloudflared ($arch)..."
    local download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}"
    
    # 使用 wget 下载
    if ! wget -q --show-progress -O "$CLOUDFLARED_PATH" "$download_url" 2>/dev/null; then
        # 如果上面失败，尝试不带 --show-progress
        if ! wget -q -O "$CLOUDFLARED_PATH" "$download_url"; then
            print_error "下载失败，请检查网络连接。"
            print_warning "提示: 如果无法连接 GitHub，可手动下载后上传到 $CLOUDFLARED_PATH"
            print_info "下载地址: $download_url"
            rm -f "$CLOUDFLARED_PATH"
            return 1
        fi
    fi

    chmod +x "$CLOUDFLARED_PATH"
    
    if [ ! -f "$CLOUDFLARED_PATH" ] || [ ! -x "$CLOUDFLARED_PATH" ]; then
        print_error "安装失败: 二进制文件无效。"
        return 1
    fi

    print_success "cloudflared 安装成功!"
    $CLOUDFLARED_PATH --version
    
    # 创建启动脚本
    create_init_script
    
    # 创建配置目录
    mkdir -p "$CONFIG_DIR"

    # 创建快捷命令
    create_shortcut
    
    print_success "安装完成!"
    printf "\n"
    print_warning "下一步: 请配置 Token (菜单选项 2)"
    print_info "如果您还没有 Token，请先在 Cloudflare 面板创建隧道。"
}

# 创建 init.d 启动脚本
create_init_script() {
    print_info "正在创建启动脚本..."
    
    cat > "$INIT_SCRIPT" << 'INITEOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10
USE_PROCD=1

PROG="/usr/bin/cloudflared"
CONFIG_DIR="/etc/cloudflared"
TOKEN_FILE="${CONFIG_DIR}/token"

get_token() {
    if [ -f "$TOKEN_FILE" ]; then
        cat "$TOKEN_FILE" | tr -d '\n\r'
    fi
}

start_service() {
    local token
    token=$(get_token)
    
    if [ -z "$token" ]; then
        echo "错误: Token 未配置。请先运行 cfd 配置 Token。"
        return 1
    fi

    procd_open_instance cloudflared
    procd_set_param command $PROG tunnel run --token "$token"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn 3600 5 5
    procd_close_instance
}

service_triggers() {
    procd_add_reload_trigger "cloudflared"
}
INITEOF

    chmod +x "$INIT_SCRIPT"
    print_success "启动脚本已创建。"
}

# 创建快捷命令
create_shortcut() {
    # 创建一个小的启动脚本
    cat > /usr/bin/cfd << 'SHORTCUTEOF'
#!/bin/sh
# Cloudflared 管理菜单快捷方式
SCRIPT_URL="https://raw.githubusercontent.com/hxzlplp7/openwrt-one-click-cloudflared/main/cloudflared_install.sh"
SCRIPT_PATH="/tmp/cloudflared_manager.sh"

# 如果本地有缓存且不超过1天，使用缓存
if [ -f "$SCRIPT_PATH" ]; then
    find "$SCRIPT_PATH" -mtime +1 -delete 2>/dev/null
fi

if [ ! -f "$SCRIPT_PATH" ]; then
    wget -q -O "$SCRIPT_PATH" "$SCRIPT_URL" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "无法下载管理脚本，请检查网络连接。"
        exit 1
    fi
    chmod +x "$SCRIPT_PATH"
fi

sh "$SCRIPT_PATH" "$@"
SHORTCUTEOF
    
    chmod +x /usr/bin/cfd
    print_success "快捷命令 'cfd' 已创建!"
}

# 配置 Token
configure_token() {
    # 显示获取 Token 的指南
    show_token_guide
    
    printf "是否已经获取到 Token? [y/N]: "
    read -r has_token
    case "$has_token" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            print_info "请先按照上述步骤获取 Token，然后再次运行此选项。"
            return
            ;;
    esac
    
    printf "\n"
    print_warning "请粘贴您的 Cloudflare Tunnel Token:"
    print_info "(以 eyJ 开头的长字符串)"
    printf "> "
    read -r token
    
    if [ -z "$token" ]; then
        print_error "Token 不能为空。"
        return 1
    fi
    
    # 简单验证 Token 格式
    case "$token" in
        eyJ*)
            ;;
        *)
            print_warning "警告: Token 通常以 'eyJ' 开头。"
            printf "确定要使用此 Token 吗? [y/N]: "
            read -r confirm
            case "$confirm" in
                [yY][eE][sS]|[yY])
                    ;;
                *)
                    print_info "已取消。"
                    return
                    ;;
            esac
            ;;
    esac
    
    mkdir -p "$CONFIG_DIR"
    printf "%s" "$token" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    print_success "Token 已保存!"
    printf "\n"
    print_info "现在可以启动服务了 (菜单选项 4)"
}

# 查看当前 Token
view_token() {
    if [ -f "$TOKEN_FILE" ]; then
        print_info "当前 Token (已脱敏):"
        local token
        token=$(cat "$TOKEN_FILE")
        local len=${#token}
        if [ $len -gt 40 ]; then
            printf "%s...%s\n" "$(echo "$token" | cut -c1-20)" "$(echo "$token" | rev | cut -c1-10 | rev)"
        else
            printf "%s\n" "$token"
        fi
        printf "\n"
        print_info "Token 长度: $len 字符"
    else
        print_warning "Token 未配置。"
        print_info "请使用菜单选项 2 配置 Token。"
    fi
}

# 启动服务
start_service() {
    if ! is_installed; then
        print_error "cloudflared 未安装，请先安装。"
        return 1
    fi
    
    if [ ! -f "$TOKEN_FILE" ]; then
        print_error "Token 未配置，请先配置 Token。"
        show_token_guide
        return 1
    fi
    
    print_info "正在启动服务..."
    /etc/init.d/cloudflared enable
    /etc/init.d/cloudflared start
    
    sleep 3
    if is_running; then
        print_success "Cloudflared 已启动!"
        printf "\n"
        print_info "隧道已连接到 Cloudflare。"
        print_info "请在 Cloudflare Zero Trust 面板配置 Public Hostname 以暴露服务。"
    else
        print_error "启动失败，请检查日志。"
        print_info "使用菜单选项 7 查看日志"
    fi
}

# 停止服务
stop_service() {
    if ! is_installed; then
        print_error "cloudflared 未安装。"
        return 1
    fi
    
    print_info "正在停止服务..."
    /etc/init.d/cloudflared stop
    /etc/init.d/cloudflared disable
    
    # 确保进程已停止
    killall cloudflared 2>/dev/null
    
    print_success "Cloudflared 已停止。"
}

# 重启服务
restart_service() {
    print_info "正在重启服务..."
    /etc/init.d/cloudflared restart
    
    sleep 3
    if is_running; then
        print_success "Cloudflared 已重启!"
    else
        print_error "重启失败，请检查日志。"
    fi
}

# 查看状态
show_status() {
    printf "Cloudflared: "
    if is_installed; then
        printf "${GREEN}已安装${PLAIN}"
        local version
        version=$($CLOUDFLARED_PATH --version 2>/dev/null | head -1)
        [ -n "$version" ] && printf " ($version)"
    else
        printf "${RED}未安装${PLAIN}"
    fi
    printf "\n"
    
    printf "服务状态: "
    if is_running; then
        printf "${GREEN}运行中${PLAIN}\n"
        local pid
        pid=$(pgrep -f "$CLOUDFLARED_PATH" | head -1)
        [ -n "$pid" ] && printf "进程 PID: %s\n" "$pid"
    else
        printf "${RED}已停止${PLAIN}\n"
    fi
    
    printf "Token: "
    if [ -f "$TOKEN_FILE" ]; then
        printf "${GREEN}已配置${PLAIN}\n"
    else
        printf "${YELLOW}未配置${PLAIN}\n"
    fi
    
    printf "开机自启: "
    if [ -f "$INIT_SCRIPT" ] && ls /etc/rc.d/S*cloudflared 2>/dev/null | grep -q .; then
        printf "${GREEN}已启用${PLAIN}\n"
    else
        printf "${RED}未启用${PLAIN}\n"
    fi
}

# 查看日志
view_logs() {
    print_info "最近的 Cloudflared 日志:"
    print_info "========================"
    logread | grep -i cloudflared | tail -30
    if [ $? -ne 0 ] || [ -z "$(logread | grep -i cloudflared)" ]; then
        print_warning "暂无日志或服务未运行。"
    fi
    print_info "========================"
}

# 卸载
uninstall_cloudflared() {
    printf "确定要卸载 Cloudflared 吗? [y/N]: "
    read -r confirm
    case "$confirm" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            print_info "取消卸载。"
            return
            ;;
    esac
    
    print_info "正在停止服务..."
    /etc/init.d/cloudflared stop 2>/dev/null
    /etc/init.d/cloudflared disable 2>/dev/null
    killall cloudflared 2>/dev/null
    
    print_info "正在删除文件..."
    rm -f "$CLOUDFLARED_PATH"
    rm -f "$INIT_SCRIPT"
    rm -rf "$CONFIG_DIR"
    rm -f /usr/bin/cfd
    rm -f /etc/rc.d/*cloudflared 2>/dev/null
    
    print_success "卸载完成!"
}

# 显示菜单
show_menu() {
    clear
    printf "${BLUE}========================================${PLAIN}\n"
    printf "${BLUE}  Cloudflared 管理脚本 (OpenWrt/iStoreOS)${PLAIN}\n"
    printf "${BLUE}========================================${PLAIN}\n"
    printf "\n"
    show_status
    printf "\n"
    printf "${BLUE}----------------------------------------${PLAIN}\n"
    printf "${GREEN}1.${PLAIN} 安装 Cloudflared\n"
    printf "${GREEN}2.${PLAIN} 配置 Token ${YELLOW}(重要)${PLAIN}\n"
    printf "${GREEN}3.${PLAIN} 查看 Token\n"
    printf "${GREEN}4.${PLAIN} 启动服务\n"
    printf "${GREEN}5.${PLAIN} 停止服务\n"
    printf "${GREEN}6.${PLAIN} 重启服务\n"
    printf "${GREEN}7.${PLAIN} 查看日志\n"
    printf "${GREEN}8.${PLAIN} 获取 Token 指南\n"
    printf "${GREEN}9.${PLAIN} 卸载\n"
    printf "${GREEN}0.${PLAIN} 退出\n"
    printf "${BLUE}----------------------------------------${PLAIN}\n"
    printf "请输入选项 [0-9]: "
    read -r choice
    
    case "$choice" in
        1) install_cloudflared ;;
        2) configure_token ;;
        3) view_token ;;
        4) start_service ;;
        5) stop_service ;;
        6) restart_service ;;
        7) view_logs ;;
        8) show_token_guide ;;
        9) uninstall_cloudflared ;;
        0) exit 0 ;;
        *) print_error "无效选项。" ;;
    esac
}

# 显示帮助
show_help() {
    printf "Cloudflared 管理脚本 (使用远程管理隧道方式)\n"
    printf "\n"
    printf "用法: %s [命令]\n" "$0"
    printf "\n"
    printf "命令:\n"
    printf "  install    安装 cloudflared\n"
    printf "  token      配置 Token\n"
    printf "  guide      显示获取 Token 的指南\n"
    printf "  start      启动服务\n"
    printf "  stop       停止服务\n"
    printf "  restart    重启服务\n"
    printf "  status     查看状态\n"
    printf "  logs       查看日志\n"
    printf "  uninstall  卸载\n"
    printf "  help       显示帮助\n"
    printf "\n"
    printf "不带参数运行将显示交互式菜单。\n"
    printf "\n"
    printf "注意: 本脚本使用 Cloudflare 远程管理隧道方式，\n"
    printf "      需要先在 Cloudflare Zero Trust 面板创建隧道获取 Token。\n"
}

# 主程序入口
main() {
    check_root
    
    if [ $# -gt 0 ]; then
        case "$1" in
            install)
                install_cloudflared
                ;;
            token)
                configure_token
                ;;
            guide)
                show_token_guide
                ;;
            start)
                start_service
                ;;
            stop)
                stop_service
                ;;
            restart)
                restart_service
                ;;
            status)
                show_status
                ;;
            logs)
                view_logs
                ;;
            uninstall)
                uninstall_cloudflared
                ;;
            help|--help|-h)
                show_help
                ;;
            *)
                print_error "未知命令: $1"
                show_help
                exit 1
                ;;
        esac
    else
        while true; do
            show_menu
            printf "\n按回车返回菜单..."
            read -r _
        done
    fi
}

main "$@"

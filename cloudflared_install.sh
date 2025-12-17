#!/bin/sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# Paths
CLOUDFLARED_PATH="/usr/bin/cloudflared"
INIT_SCRIPT="/etc/init.d/cloudflared"
CONFIG_DIR="/etc/cloudflared"
LOG_FILE="/var/log/cloudflared.log"

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 此脚本必须以 root 身份运行!${PLAIN}"
        exit 1
    fi
}

get_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="arm"
            ;;
        *)
            echo -e "${RED}不支持的架构: $ARCH${PLAIN}"
            return 1
            ;;
    esac
    echo $ARCH
}

install_cloudflared() {
    ARCH=$(get_arch)
    if [ $? -ne 0 ]; then
        exit 1
    fi

    echo -e "${BLUE}正在安装依赖...${PLAIN}"
    opkg update
    opkg install wget-ssl ca-certificates ca-bundle libopenssl

    echo -e "${BLUE}正在下载 cloudflared ($ARCH)...${PLAIN}"
    # Use valid download URL. Sometimes official GitHub releases are slow.
    # We will try official first.
    DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}"
    
    wget -O ${CLOUDFLARED_PATH} ${DOWNLOAD_URL}
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，请检查网络连接。${PLAIN}"
        return 1
    fi

    chmod +x ${CLOUDFLARED_PATH}
    
    if [ ! -f "${CLOUDFLARED_PATH}" ]; then
        echo -e "${RED}安装失败: 未找到二进制文件。${PLAIN}"
        return 1
    fi

    echo -e "${GREEN}cloudflared 安装成功!${PLAIN}"
    
    # Check version
    ${CLOUDFLARED_PATH} --version
    
    # Setup Init Script
    create_init_script

    # Create shortcut
    cp "$0" /usr/bin/cloudflared-menu
    chmod +x /usr/bin/cloudflared-menu
    echo -e "${GREEN}Shortcut 'cloudflared-menu' created!${PLAIN}"
}

create_init_script() {
    echo -e "${BLUE}正在创建启动脚本...${PLAIN}"
    cat > ${INIT_SCRIPT} <<EOF
#!/bin/sh /etc/rc.common

START=99
STOP=10
USE_PROCD=1

PROG=${CLOUDFLARED_PATH}
CONFIG_DIR="${CONFIG_DIR}"

get_token() {
    # Try to read token from config file or uci (if implemented)
    # For simplicity, we assume token is stored in a simple text file or passed as arg
    if [ -f "\$CONFIG_DIR/token" ]; then
        cat "\$CONFIG_DIR/token"
    fi
}

start_service() {
    local token=\$(get_token)
    
    if [ -z "\$token" ]; then
        echo "Token 未找到 (Token not found)。请先配置 Token。"
        return 1
    fi

    procd_open_instance
    procd_set_param command \$PROG tunnel run --token \$token
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn \${respawn_threshold:-3600} \${respawn_timeout:-5} \${respawn_retry:-5}
    procd_close_instance
}
EOF
    chmod +x ${INIT_SCRIPT}
    mkdir -p ${CONFIG_DIR}
    echo -e "${GREEN}启动脚本已创建。${PLAIN}"
}

configure_token() {
    echo -e "${YELLOW}请输入您的 Cloudflare Tunnel Token:${PLAIN}"
    read -r TOKEN
    
    if [ -z "$TOKEN" ]; then
        echo -e "${RED}Token 不能为空。${PLAIN}"
        return
    fi
    
    mkdir -p ${CONFIG_DIR}
    echo "$TOKEN" > "${CONFIG_DIR}/token"
    echo -e "${GREEN}Token 已保存。${PLAIN}"
}

start_cf() {
    if [ ! -f "${INIT_SCRIPT}" ]; then
        echo -e "${RED}服务未安装。${PLAIN}"
        return
    fi
    /etc/init.d/cloudflared enable
    /etc/init.d/cloudflared start
    echo -e "${GREEN}Cloudflared 已启动。${PLAIN}"
}

stop_cf() {
    if [ ! -f "${INIT_SCRIPT}" ]; then
        echo -e "${RED}服务未安装。${PLAIN}"
        return
    fi
    /etc/init.d/cloudflared stop
    /etc/init.d/cloudflared disable
    echo -e "${GREEN}Cloudflared 已停止。${PLAIN}"
}

restart_cf() {
    stop_cf
    sleep 1
    start_cf
}

uninstall_cf() {
    echo -e "${YELLOW}正在停止服务...${PLAIN}"
    stop_cf
    
    echo -e "${YELLOW}正在删除文件...${PLAIN}"
    rm -f ${CLOUDFLARED_PATH}
    rm -f ${INIT_SCRIPT}
    rm -rf ${CONFIG_DIR}
    rm -f /usr/bin/cloudflared-menu
    
    echo -e "${GREEN}卸载成功。${PLAIN}"
}

show_status() {
    if [ -f "${INIT_SCRIPT}" ]; then
        if /etc/init.d/cloudflared running; then
            echo -e "${GREEN}运行中${PLAIN}"
        else
            echo -e "${RED}已停止${PLAIN}"
        fi
    else
        echo -e "${RED}未安装${PLAIN}"
    fi
}

show_menu() {
    clear
    echo -e "${BLUE}Cloudflared 管理脚本 (OpenWrt/iStoreOS)${PLAIN}"
    echo -e "${BLUE}---------------------------------------${PLAIN}"
    echo -e "${GREEN}1.${PLAIN} 安装 Cloudflared"
    echo -e "${GREEN}2.${PLAIN} 配置 Token"
    echo -e "${GREEN}3.${PLAIN} 启动服务"
    echo -e "${GREEN}4.${PLAIN} 停止服务"
    echo -e "${GREEN}5.${PLAIN} 重启服务"
    echo -e "${GREEN}6.${PLAIN} 卸载"
    echo -e "${GREEN}7.${PLAIN} 查看状态"
    echo -e "${GREEN}0.${PLAIN} 退出"
    echo -e "${BLUE}---------------------------------------${PLAIN}"
    echo "当前状态: $(show_status)"
    echo -e "${BLUE}---------------------------------------${PLAIN}"
    read -p "请输入选项: " choice
    
    case $choice in
        1) install_cloudflared ;;
        2) configure_token ;;
        3) start_cf ;;
        4) stop_cf ;;
        5) restart_cf ;;
        6) uninstall_cf ;;
        7) show_status; read -p "按回车继续..." ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项。${PLAIN}" ;;
    esac
}

# Main
check_root

if [ $# -gt 0 ]; then
    case $1 in
        install) install_cloudflared ;;
        start) start_cf ;;
        stop) stop_cf ;;
        restart) restart_cf ;;
        uninstall) uninstall_cf ;;
        *) echo "Usage: $0 {install|start|stop|restart|uninstall}" ;;
    esac
else
    while true; do
        show_menu
        echo -e "\n按回车返回菜单..."
        read temp
    done
fi

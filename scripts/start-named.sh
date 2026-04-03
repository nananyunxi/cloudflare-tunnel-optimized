#!/bin/bash

#######################################################
# Cloudflare Tunnel 优化版 - 命名隧道启动脚本
# 支持 macOS / Linux
# 需要登录 Cloudflare 账号
# 支持自定义域名
#######################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认配置
CONFIG_DIR="$HOME/.cloudflared"
CONFIG_FILE="$CONFIG_DIR/config.yml"
LOG_DIR="$CONFIG_DIR/logs"
PID_FILE="$CONFIG_DIR/tunnel.pid"

# 打印横幅
print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║     Cloudflare Tunnel 优化版 - 命名隧道启动脚本       ║"
    echo "║       支持自定义域名 · 固定隧道 · 企业级安全           ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# 检查 cloudflared
check_cloudflared() {
    command -v cloudflared &> /dev/null
}

# 安装 cloudflared
install_cloudflared() {
    local os=$(detect_os)
    
    echo -e "${YELLOW}正在安装 cloudflared...${NC}"
    
    case $os in
        macos)
            if command -v brew &> /dev/null; then
                brew install cloudflared
            else
                curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64 -o /tmp/cloudflared
                chmod +x /tmp/cloudflared
                sudo mv /tmp/cloudflared /usr/local/bin/
            fi
            ;;
        linux)
            if command -v apt-get &> /dev/null; then
                curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
                sudo dpkg -i /tmp/cloudflared.deb || sudo apt-get install -f -y
                rm -f /tmp/cloudflared.deb
            elif command -v yum &> /dev/null; then
                curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.rpm -o /tmp/cloudflared.rpm
                sudo rpm -i /tmp/cloudflared.rpm
                rm -f /tmp/cloudflared.rpm
            else
                curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /tmp/cloudflared
                chmod +x /tmp/cloudflared
                sudo mv /tmp/cloudflared /usr/local/bin/
            fi
            ;;
        *)
            echo -e "${RED}不支持的操作系统${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✓ cloudflared 安装完成${NC}"
}

# 检查登录状态
check_login() {
    if [[ -f "$CONFIG_DIR/cert.pem" ]]; then
        return 0
    else
        return 1
    fi
}

# 登录 Cloudflare
login_cloudflare() {
    echo -e "${CYAN}即将打开浏览器进行 Cloudflare 登录授权...${NC}"
    echo -e "${YELLOW}请在浏览器中选择要使用的域名并授权${NC}"
    echo ""
    
    cloudflared tunnel login
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ 登录成功${NC}"
    else
        echo -e "${RED}✗ 登录失败${NC}"
        exit 1
    fi
}

# 列出现有隧道
list_tunnels() {
    echo -e "${CYAN}现有隧道列表:${NC}"
    cloudflared tunnel list
}

# 创建隧道
create_tunnel() {
    echo -e "${CYAN}请输入隧道名称 (仅字母、数字、连字符):${NC} "
    read -r tunnel_name
    
    if [[ -z "$tunnel_name" ]]; then
        echo -e "${RED}隧道名称不能为空${NC}"
        exit 1
    fi
    
    # 验证名称格式
    if [[ ! "$tunnel_name" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo -e "${RED}隧道名称只能包含字母、数字和连字符${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}正在创建隧道: $tunnel_name ...${NC}"
    
    if cloudflared tunnel create "$tunnel_name"; then
        echo -e "${GREEN}✓ 隧道创建成功${NC}"
        echo "$tunnel_name"
    else
        echo -e "${RED}✗ 隧道创建失败${NC}"
        exit 1
    fi
}

# 配置隧道
configure_tunnel() {
    local tunnel_name=$1
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    
    # 获取隧道 ID
    local tunnel_info=$(cloudflared tunnel list 2>/dev/null | grep "$tunnel_name" || true)
    
    if [[ -z "$tunnel_info" ]]; then
        echo -e "${RED}无法找到隧道: $tunnel_name${NC}"
        exit 1
    fi
    
    local tunnel_id=$(echo "$tunnel_info" | awk '{print $1}')
    
    echo -e "${GREEN}✓ 隧道 ID: $tunnel_id${NC}"
    
    # 提示输入域名和端口配置
    echo ""
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}配置隧道路由${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    
    echo -e "${CYAN}请输入子域名 (如: app, api, www):${NC} "
    read -r subdomain
    
    echo -e "${CYAN}请输入域名 (如: yourdomain.com):${NC} "
    read -r domain
    
    echo -e "${CYAN}请输入本地服务端口 [默认: 8080]:${NC} "
    read -r local_port
    local_port=${local_port:-8080}
    
    local full_hostname="${subdomain}.${domain}"
    
    # 配置 DNS 路由
    echo -e "${YELLOW}正在配置 DNS 路由: $full_hostname -> 隧道 $tunnel_name${NC}"
    cloudflared tunnel route dns "$tunnel_name" "$full_hostname"
    
    # 创建配置文件
    cat > "$CONFIG_FILE" << EOF
# Cloudflare Tunnel 配置文件
# 由 cloudflare-tunnel-optimized 自动生成

tunnel: $tunnel_name
credentials-file: $CONFIG_DIR/$tunnel_id.json

ingress:
  - hostname: $full_hostname
    service: http://localhost:$local_port
    originRequest:
      connectTimeout: 30s
      tcpKeepAlive: 30s
      noTLSVerify: true
  
  # 默认规则 (必须)
  - service: http_status:404
EOF
    
    echo -e "${GREEN}✓ 配置文件已创建: $CONFIG_FILE${NC}"
    echo -e "${GREEN}✓ DNS 路由已配置: https://$full_hostname${NC}"
}

# 启动隧道
start_tunnel() {
    local tunnel_name=$1
    
    # 检查是否已有隧道在运行
    if [[ -f "$PID_FILE" ]]; then
        local old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            echo -e "${YELLOW}已有隧道在运行 (PID: $old_pid)${NC}"
            echo -e "${CYAN}是否停止并重启? [Y/n]:${NC} "
            read -r restart
            if [[ ! "$restart" =~ ^[Nn]$ ]]; then
                kill "$old_pid" 2>/dev/null || true
                rm -f "$PID_FILE"
                sleep 2
            else
                exit 0
            fi
        fi
    fi
    
    echo -e "${YELLOW}正在启动隧道: $tunnel_name ...${NC}"
    
    # 后台启动
    nohup cloudflared tunnel run \
        --config "$CONFIG_FILE" \
        --edge-ip-version auto \
        --retries 5 \
        > "$LOG_DIR/tunnel.log" 2>&1 &
    
    local pid=$!
    echo $pid > "$PID_FILE"
    
    sleep 3
    
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ 隧道启动成功！${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}📌 隧道信息:${NC}"
    echo -e "   隧道名称: ${GREEN}$tunnel_name${NC}"
    echo -e "   隧道 PID: ${GREEN}$pid${NC}"
    echo -e "   配置文件: ${GREEN}$CONFIG_FILE${NC}"
    echo -e "   日志文件: ${GREEN}$LOG_DIR/tunnel.log${NC}"
    echo ""
    echo -e "${CYAN}💡 提示:${NC}"
    echo -e "   - 使用 ${GREEN}./stop.sh${NC} 停止隧道"
    echo -e "   - 编辑 ${GREEN}$CONFIG_FILE${NC} 添加更多服务"
    echo ""
}

# 主函数
main() {
    print_banner
    
    # 检查 cloudflared
    if ! check_cloudflared; then
        echo -e "${YELLOW}cloudflared 未安装${NC}"
        install_cloudflared
    else
        echo -e "${GREEN}✓ cloudflared 已安装: $(cloudflared --version | head -1)${NC}"
    fi
    
    # 检查登录状态
    if ! check_login; then
        echo -e "${YELLOW}尚未登录 Cloudflare${NC}"
        login_cloudflare
    else
        echo -e "${GREEN}✓ 已登录 Cloudflare${NC}"
    fi
    
    # 列出现有隧道
    echo ""
    list_tunnels
    echo ""
    
    # 选择操作
    echo -e "${CYAN}请选择操作:${NC}"
    echo -e "  1) 使用现有隧道"
    echo -e "  2) 创建新隧道"
    echo ""
    echo -e "${CYAN}请输入选项 [1/2]:${NC} "
    read -r choice
    
    case $choice in
        1)
            echo -e "${CYAN}请输入隧道名称:${NC} "
            read -r tunnel_name
            ;;
        2)
            tunnel_name=$(create_tunnel)
            configure_tunnel "$tunnel_name"
            ;;
        *)
            echo -e "${RED}无效选项${NC}"
            exit 1
            ;;
    esac
    
    if [[ -n "$tunnel_name" ]]; then
        start_tunnel "$tunnel_name"
    fi
}

# 运行
main

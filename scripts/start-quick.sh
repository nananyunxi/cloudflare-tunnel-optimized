#!/bin/bash

#######################################################
# Cloudflare Tunnel 优化版 - 快速隧道启动脚本
# 支持 macOS / Linux
# 无需注册，即开即用
#######################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_PORT=8080
LOG_DIR="$HOME/.cloudflared/logs"
PID_FILE="$HOME/.cloudflared/tunnel.pid"

# 打印横幅
print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║     Cloudflare Tunnel 优化版 - 快速隧道启动脚本       ║"
    echo "║          免费 · 稳定 · 无需注册 · 即开即用            ║"
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

# 检查 cloudflared 是否已安装
check_cloudflared() {
    if command -v cloudflared &> /dev/null; then
        return 0
    else
        return 1
    fi
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
                echo -e "${YELLOW}Homebrew 未安装，使用二进制安装...${NC}"
                curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64 -o /tmp/cloudflared
                chmod +x /tmp/cloudflared
                sudo mv /tmp/cloudflared /usr/local/bin/
            fi
            ;;
        linux)
            if command -v apt-get &> /dev/null; then
                # Debian/Ubuntu
                curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
                sudo dpkg -i /tmp/cloudflared.deb || sudo apt-get install -f -y
                rm -f /tmp/cloudflared.deb
            elif command -v yum &> /dev/null; then
                # RHEL/CentOS
                curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.rpm -o /tmp/cloudflared.rpm
                sudo rpm -i /tmp/cloudflared.rpm
                rm -f /tmp/cloudflared.rpm
            else
                # 通用二进制安装
                curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /tmp/cloudflared
                chmod +x /tmp/cloudflared
                sudo mv /tmp/cloudflared /usr/local/bin/
            fi
            ;;
        *)
            echo -e "${RED}不支持的操作系统: $OSTYPE${NC}"
            echo "请手动安装 cloudflared: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✓ cloudflared 安装完成${NC}"
}

# 检查端口是否被占用
check_port() {
    local port=$1
    
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # 端口被占用
    else
        return 1  # 端口空闲
    fi
}

# 获取本地服务端口
get_port() {
    local port=$1
    
    if [[ -z "$port" ]]; then
        echo -e "${CYAN}请输入要暴露的本地端口 [默认: $DEFAULT_PORT]:${NC} "
        read -r input_port
        port=${input_port:-$DEFAULT_PORT}
    fi
    
    echo "$port"
}

# 启动快速隧道
start_quick_tunnel() {
    local port=$1
    
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}启动参数配置${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
    
    # 检查本地服务是否运行
    if ! check_port $port; then
        echo -e "${YELLOW}⚠ 警告: 本地端口 $port 没有服务在监听${NC}"
        echo -e "${YELLOW}请确保你的本地服务已启动，或者稍后启动服务${NC}"
        echo -e "${CYAN}是否继续启动隧道? [Y/n]:${NC} "
        read -r continue
        if [[ "$continue" =~ ^[Nn]$ ]]; then
            echo "已取消"
            exit 0
        fi
    else
        echo -e "${GREEN}✓ 本地端口 $port 已有服务在监听${NC}"
    fi
    
    # 创建日志目录
    mkdir -p "$LOG_DIR"
    mkdir -p "$HOME/.cloudflared"
    
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
                echo "已取消"
                exit 0
            fi
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}正在启动 Cloudflare Tunnel...${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
    
    # 启动隧道（后台运行）
    nohup cloudflared tunnel \
        --url "http://localhost:$port" \
        --edge-ip-version auto \
        --retries 5 \
        --loglevel info \
        --logfile "$LOG_DIR/tunnel.log" \
        > "$LOG_DIR/tunnel-output.log" 2>&1 &
    
    local pid=$!
    echo $pid > "$PID_FILE"
    
    # 等待隧道建立
    echo -e "${YELLOW}正在等待隧道建立...${NC}"
    sleep 5
    
    # 从日志中提取隧道 URL
    local tunnel_url=""
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        tunnel_url=$(grep -o 'https://[^ ]*\.trycloudflare\.com' "$LOG_DIR/tunnel-output.log" 2>/dev/null | head -1 || true)
        if [[ -n "$tunnel_url" ]]; then
            break
        fi
        sleep 1
        ((attempt++))
    done
    
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Cloudflare Tunnel 启动成功！${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}📌 隧道信息:${NC}"
    echo -e "   本地端口: ${GREEN}$port${NC}"
    echo -e "   隧道 PID: ${GREEN}$pid${NC}"
    if [[ -n "$tunnel_url" ]]; then
        echo -e "   公网地址: ${GREEN}$tunnel_url${NC}"
    else
        echo -e "   公网地址: ${YELLOW}请查看日志获取${NC}"
    fi
    echo ""
    echo -e "${CYAN}📁 日志文件:${NC}"
    echo -e "   $LOG_DIR/tunnel.log"
    echo -e "   $LOG_DIR/tunnel-output.log"
    echo ""
    echo -e "${CYAN}💡 提示:${NC}"
    echo -e "   - 隧道正在后台运行，关闭此窗口不影响服务"
    echo -e "   - 使用 ${GREEN}./stop.sh${NC} 停止隧道"
    echo -e "   - 使用 ${GREEN}cloudflared tunnel --url http://localhost:$port${NC} 前台运行查看实时日志"
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
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
    
    # 获取端口
    local port=$(get_port "$1")
    
    # 启动隧道
    start_quick_tunnel "$port"
}

# 运行
main "$@"

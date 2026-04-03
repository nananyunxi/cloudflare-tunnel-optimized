#!/bin/bash

#######################################################
# Cloudflare Tunnel 优化版 - 自动重连脚本
# 支持 macOS / Linux
# 检测断线自动重连，并通知用户新的隧道链接
#######################################################

set -e

# 配置
CHECK_INTERVAL=30          # 检查间隔（秒）
LOG_DIR="$HOME/.cloudflared/logs"
PID_FILE="$HOME/.cloudflared/tunnel.pid"
TUNNEL_URL_FILE="$HOME/.cloudflared/tunnel_url.txt"
LOCAL_PORT=8080            # 默认端口，可通过参数指定

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# 获取当前隧道 URL
get_tunnel_url() {
    if [[ -f "$LOG_DIR/tunnel-output.log" ]]; then
        grep -o 'https://[^ ]*\.trycloudflare\.com' "$LOG_DIR/tunnel-output.log" 2>/dev/null | tail -1
    fi
}

# 启动隧道
start_tunnel() {
    local port=$1
    
    log_info "启动隧道 (端口: $port)..."
    
    # 确保目录存在
    mkdir -p "$LOG_DIR"
    mkdir -p "$HOME/.cloudflared"
    
    # 启动 cloudflared
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
    sleep 8
    
    # 获取并保存隧道 URL
    local new_url=$(get_tunnel_url)
    if [[ -n "$new_url" ]]; then
        echo "$new_url" > "$TUNNEL_URL_FILE"
        log_info "✅ 隧道启动成功！"
        log_info "📌 公网地址: $new_url"
        echo ""
        echo "══════════════════════════════════════════════════════"
        echo "  🌐 隧道链接: $new_url"
        echo "══════════════════════════════════════════════════════"
        echo ""
    else
        log_error "⚠️ 隧道启动中，请等待..."
    fi
}

# 停止隧道
stop_tunnel() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            log_info "已停止隧道"
        fi
        rm -f "$PID_FILE"
    fi
    
    # 清理所有 cloudflared 进程
    pkill -f "cloudflared tunnel" 2>/dev/null || true
}

# 检查隧道是否正常
check_tunnel() {
    local port=$1
    
    # 检查进程是否存在
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "PROCESS_DEAD"
            return
        fi
    else
        echo "NO_PID"
        return
    fi
    
    # 检查本地服务是否运行
    if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "LOCAL_SERVICE_DOWN"
        return
    fi
    
    # 检查隧道 URL 是否有效
    local current_url=$(get_tunnel_url)
    if [[ -z "$current_url" ]]; then
        echo "NO_URL"
        return
    fi
    
    echo "OK"
}

# 主函数
main() {
    local port=${1:-$LOCAL_PORT}
    
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║     Cloudflare Tunnel - 自动重连守护进程              ║"
    echo "║     断线自动重连 · 实时监控 · 链接通知              ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    log_info "监控端口: $port"
    log_info "检查间隔: ${CHECK_INTERVAL}秒"
    log_info "日志目录: $LOG_DIR"
    echo ""
    
    # 初始启动
    start_tunnel "$port"
    
    log_info "守护进程已启动，按 Ctrl+C 停止监控"
    echo ""
    
    # 主循环
    while true; do
        sleep $CHECK_INTERVAL
        
        local status=$(check_tunnel "$port")
        
        case $status in
            "PROCESS_DEAD")
                log_error "⚠️ 隧道进程已停止，准备重连..."
                start_tunnel "$port"
                ;;
            "LOCAL_SERVICE_DOWN")
                log_error "⚠️ 本地服务已停止，隧道将继续运行..."
                ;;
            "NO_URL")
                log_error "⚠️ 隧道链接丢失，准备重连..."
                start_tunnel "$port"
                ;;
            "OK")
                # 隧道正常运行，检查 URL 是否有变化
                local current_url=$(get_tunnel_url)
                local saved_url=$(cat "$TUNNEL_URL_FILE" 2>/dev/null || echo "")
                
                if [[ "$current_url" != "$saved_url" ]] && [[ -n "$current_url" ]]; then
                    echo "$current_url" > "$TUNNEL_URL_FILE"
                    log_info "📌 隧道链接已更新: $current_url"
                fi
                ;;
        esac
    done
}

# 处理信号
trap 'echo ""; log_info "收到停止信号，正在退出..."; stop_tunnel; exit 0' SIGINT SIGTERM

# 运行
main "$@"
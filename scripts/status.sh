#!/bin/bash

#######################################################
# Cloudflare Tunnel 优化版 - 状态检查脚本
# 支持 macOS / Linux
#######################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PID_FILE="$HOME/.cloudflared/tunnel.pid"
LOG_DIR="$HOME/.cloudflared/logs"

echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}        Cloudflare Tunnel 状态检查${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo ""

# 检查 cloudflared 是否安装
echo -e "${CYAN}【程序状态】${NC}"
if command -v cloudflared &> /dev/null; then
    VERSION=$(cloudflared --version 2>&1 | head -1)
    echo -e "  cloudflared: ${GREEN}已安装${NC}"
    echo -e "  版本: ${GREEN}$VERSION${NC}"
else
    echo -e "  cloudflared: ${RED}未安装${NC}"
    exit 1
fi

echo ""

# 检查隧道进程
echo -e "${CYAN}【隧道状态】${NC}"
if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "  状态: ${GREEN}运行中${NC}"
        echo -e "  PID: ${GREEN}$PID${NC}"
        
        # 获取进程运行时间
        if command -v ps &> /dev/null; then
            UPTIME=$(ps -o etime= -p "$PID" 2>/dev/null | tr -d ' ')
            if [[ -n "$UPTIME" ]]; then
                echo -e "  运行时间: ${GREEN}$UPTIME${NC}"
            fi
        fi
        
        # 获取内存使用
        if command -v ps &> /dev/null; then
            MEM=$(ps -o rss= -p "$PID" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
            if [[ -n "$MEM" ]]; then
                echo -e "  内存使用: ${GREEN}$MEM${NC}"
            fi
        fi
    else
        echo -e "  状态: ${RED}已停止${NC}"
        echo -e "  ${YELLOW}PID 文件存在但进程已终止${NC}"
        rm -f "$PID_FILE"
    fi
else
    # 尝试通过进程名查找
    PID=$(pgrep -f "cloudflared tunnel" | head -1)
    if [[ -n "$PID" ]]; then
        echo -e "  状态: ${GREEN}运行中${NC}"
        echo -e "  PID: ${GREEN}$PID${NC} (未通过脚本启动)"
    else
        echo -e "  状态: ${YELLOW}未运行${NC}"
    fi
fi

echo ""

# 检查隧道 URL
echo -e "${CYAN}【隧道信息】${NC}"
if [[ -f "$LOG_DIR/tunnel-output.log" ]]; then
    TUNNEL_URL=$(grep -o 'https://[^ ]*\.trycloudflare\.com' "$LOG_DIR/tunnel-output.log" 2>/dev/null | tail -1)
    if [[ -n "$TUNNEL_URL" ]]; then
        echo -e "  公网地址: ${GREEN}$TUNNEL_URL${NC}"
    else
        echo -e "  公网地址: ${YELLOW}未找到${NC}"
    fi
else
    echo -e "  日志文件: ${YELLOW}不存在${NC}"
fi

echo ""

# 检查端口
echo -e "${CYAN}【本地服务】${NC}"
if [[ -f "$LOG_DIR/tunnel-output.log" ]]; then
    PORT=$(grep -o 'localhost:[0-9]*' "$LOG_DIR/tunnel-output.log" 2>/dev/null | head -1 | cut -d: -f2)
    if [[ -n "$PORT" ]]; then
        echo -e "  本地端口: ${GREEN}$PORT${NC}"
        if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo -e "  端口状态: ${GREEN}有服务监听${NC}"
        else
            echo -e "  端口状态: ${YELLOW}无服务监听${NC}"
        fi
    fi
fi

echo ""

# 检查日志
echo -e "${CYAN}【日志文件】${NC}"
if [[ -d "$LOG_DIR" ]]; then
    LOG_SIZE=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1)
    echo -e "  日志目录: ${GREEN}$LOG_DIR${NC}"
    echo -e "  日志大小: ${GREEN}$LOG_SIZE${NC}"
    
    # 显示最近的错误
    if [[ -f "$LOG_DIR/tunnel.log" ]]; then
        ERRORS=$(grep -i "error\|fail\|warn" "$LOG_DIR/tunnel.log" 2>/dev/null | tail -3)
        if [[ -n "$ERRORS" ]]; then
            echo -e "  最近警告/错误:"
            echo "$ERRORS" | while read line; do
                echo -e "    ${YELLOW}$line${NC}"
            done
        fi
    fi
else
    echo -e "  日志目录: ${YELLOW}不存在${NC}"
fi

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"

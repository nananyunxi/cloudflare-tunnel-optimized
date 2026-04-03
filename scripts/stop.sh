#!/bin/bash

#######################################################
# Cloudflare Tunnel 优化版 - 停止脚本
# 支持 macOS / Linux
#######################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PID_FILE="$HOME/.cloudflared/tunnel.pid"

echo -e "${CYAN}正在停止 Cloudflare Tunnel...${NC}"

if [[ -f "$PID_FILE" ]]; then
    pid=$(cat "$PID_FILE")
    
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        rm -f "$PID_FILE"
        echo -e "${GREEN}✓ 隧道已停止 (PID: $pid)${NC}"
    else
        rm -f "$PID_FILE"
        echo -e "${YELLOW}隧道进程已不存在，清理 PID 文件${NC}"
    fi
else
    # 尝试通过进程名查找
    pid=$(pgrep -f "cloudflared tunnel" | head -1)
    
    if [[ -n "$pid" ]]; then
        kill "$pid"
        echo -e "${GREEN}✓ 隧道已停止 (PID: $pid)${NC}"
    else
        echo -e "${YELLOW}没有找到运行中的隧道${NC}"
    fi
fi

# 清理所有 cloudflared 进程（可选）
echo -e "${CYAN}是否停止所有 cloudflared 进程? [y/N]:${NC} "
read -r kill_all

if [[ "$kill_all" =~ ^[Yy]$ ]]; then
    pkill -f "cloudflared" 2>/dev/null || true
    echo -e "${GREEN}✓ 所有 cloudflared 进程已停止${NC}"
fi

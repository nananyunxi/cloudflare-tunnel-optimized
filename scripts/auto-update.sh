#!/bin/bash

#######################################################
# Cloudflare Tunnel 优化版 - 自动更新检查脚本
# 支持 macOS / Linux
# 可后台运行，自动检查更新
#######################################################

# 后台模式（不交互）
BACKGROUND_MODE=true

# 检查 cloudflared 是否安装
if ! command -v cloudflared &> /dev/null; then
    echo "$(date): cloudflared 未安装" >> /tmp/cloudflared_auto_update.log
    exit 1
fi

# 获取当前版本
CURRENT_VERSION=$(cloudflared --version 2>&1 | grep -oP 'cloudflared version \K[\d.]+' || cloudflared --version 2>&1 | awk '{print $NF}')

# 获取最新版本
LATEST_VERSION=$(curl -sI "https://github.com/cloudflare/cloudflared/releases/latest" 2>/dev/null | grep -i "location:" | sed 's/.*tag\/v\?//' | tr -d '\r\n')

if [[ -z "$LATEST_VERSION" ]]; then
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/cloudflare/cloudflared/releases/latest" 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\?//' | sed 's/".*//')
fi

if [[ -z "$LATEST_VERSION" ]]; then
    echo "$(date): 无法获取最新版本" >> /tmp/cloudflared_auto_update.log
    exit 0
fi

# 比较版本
if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    echo "$(date): 已是最新版本 $CURRENT_VERSION" >> /tmp/cloudflared_auto_update.log
else
    echo "$(date): 发现新版本 $LATEST_VERSION (当前 $CURRENT_VERSION)" >> /tmp/cloudflared_auto_update.log
    
    # 自动更新
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
    esac
    
    DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${OS}-${ARCH}"
    
    if [[ "$OS" == "linux" ]]; then
        if command -v apt-get &> /dev/null; then
            curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb" -o /tmp/cloudflared.deb
            sudo dpkg -i /tmp/cloudflared.deb || sudo apt-get install -f -y
            rm -f /tmp/cloudflared.deb
        fi
    fi
    
    NEW_VERSION=$(cloudflared --version 2>&1 | grep -oP 'cloudflared version \K[\d.]+' || cloudflared --version 2>&1 | awk '{print $NF}')
    echo "$(date): 更新完成，新版本 $NEW_VERSION" >> /tmp/cloudflared_auto_update.log
fi
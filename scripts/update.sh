#!/bin/bash

#######################################################
# Cloudflare Tunnel 优化版 - 更新检查脚本
# 支持 macOS / Linux
#######################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}        Cloudflare Tunnel 更新检查${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo ""

# 检查 cloudflared 是否安装
if ! command -v cloudflared &> /dev/null; then
    echo -e "${RED}cloudflared 未安装${NC}"
    echo "请先运行 start-quick.sh 安装"
    exit 1
fi

# 获取当前版本
CURRENT_VERSION=$(cloudflared --version 2>&1 | grep -oP 'cloudflared version \K[\d.]+' || cloudflared --version 2>&1 | awk '{print $NF}')
echo -e "${CYAN}当前版本: ${GREEN}$CURRENT_VERSION${NC}"
echo ""

# 获取最新版本
echo -e "${CYAN}正在检查最新版本...${NC}"
LATEST_VERSION=$(curl -sI "https://github.com/cloudflare/cloudflared/releases/latest" 2>/dev/null | grep -i "location:" | sed 's/.*tag\/v\?//' | tr -d '\r\n')

if [[ -z "$LATEST_VERSION" ]]; then
    # 备用方法：通过 API 获取
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/cloudflare/cloudflared/releases/latest" 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\?//' | sed 's/".*//')
fi

if [[ -z "$LATEST_VERSION" ]]; then
    echo -e "${YELLOW}无法获取最新版本信息${NC}"
    echo "请手动检查: https://github.com/cloudflare/cloudflared/releases"
    exit 0
fi

echo -e "${CYAN}最新版本: ${GREEN}$LATEST_VERSION${NC}"
echo ""

# 比较版本
if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    echo -e "${GREEN}✓ 已是最新版本${NC}"
else
    echo -e "${YELLOW}发现新版本!${NC}"
    echo ""
    
    # 版本比较
    CURRENT_ARR=(${CURRENT_VERSION//./ })
    LATEST_ARR=(${LATEST_VERSION//./ })
    
    NEED_UPDATE=false
    for i in 0 1 2; do
        if [[ ${LATEST_ARR[$i]:-0} -gt ${CURRENT_ARR[$i]:-0} ]]; then
            NEED_UPDATE=true
            break
        elif [[ ${LATEST_ARR[$i]:-0} -lt ${CURRENT_ARR[$i]:-0} ]]; then
            break
        fi
    done
    
    if $NEED_UPDATE; then
        echo -e "${CYAN}是否立即更新? [Y/n]:${NC} "
        read -r answer
        
        if [[ ! "$answer" =~ ^[Nn]$ ]]; then
            echo ""
            echo -e "${YELLOW}正在更新 cloudflared...${NC}"
            
            # 检测操作系统和架构
            OS=$(uname -s | tr '[:upper:]' '[:lower:]')
            ARCH=$(uname -m)
            
            case $ARCH in
                x86_64|amd64) ARCH="amd64" ;;
                aarch64|arm64) ARCH="arm64" ;;
            esac
            
            DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${OS}-${ARCH}"
            
            if [[ "$OS" == "darwin" ]]; then
                # macOS 可能通过 Homebrew 安装
                if command -v brew &> /dev/null; then
                    brew upgrade cloudflared
                else
                    curl -L "$DOWNLOAD_URL" -o /tmp/cloudflared
                    chmod +x /tmp/cloudflared
                    sudo mv /tmp/cloudflared /usr/local/bin/
                fi
            elif [[ "$OS" == "linux" ]]; then
                if command -v apt-get &> /dev/null; then
                    curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb" -o /tmp/cloudflared.deb
                    sudo dpkg -i /tmp/cloudflared.deb || sudo apt-get install -f -y
                    rm -f /tmp/cloudflared.deb
                elif command -v yum &> /dev/null; then
                    curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.rpm" -o /tmp/cloudflared.rpm
                    sudo rpm -U /tmp/cloudflared.rpm
                    rm -f /tmp/cloudflared.rpm
                else
                    curl -L "$DOWNLOAD_URL" -o /tmp/cloudflared
                    chmod +x /tmp/cloudflared
                    sudo mv /tmp/cloudflared /usr/local/bin/
                fi
            fi
            
            # 验证更新
            NEW_VERSION=$(cloudflared --version 2>&1 | grep -oP 'cloudflared version \K[\d.]+' || cloudflared --version 2>&1 | awk '{print $NF}')
            echo ""
            echo -e "${GREEN}✓ 更新完成!${NC}"
            echo -e "${CYAN}新版本: ${GREEN}$NEW_VERSION${NC}"
        fi
    fi
fi

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"

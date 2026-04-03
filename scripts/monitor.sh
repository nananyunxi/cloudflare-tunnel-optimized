#!/bin/bash

#######################################################
# Cloudflare Tunnel 优化版 - Web 监控服务器
# 提供 Web 界面监控隧道状态
#######################################################

# 配置
PORT=9090
LOG_DIR="$HOME/.cloudflared/logs"
PID_FILE="$HOME/.cloudflared/tunnel.pid"
TUNNEL_URL_FILE="$HOME/.cloudflared/tunnel_url.txt"

# 获取隧道信息
get_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            local uptime=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')
            local mem=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
            echo "running|$pid|$uptime|$mem"
            return
        fi
    fi
    echo "stopped|0|0|0"
}

get_tunnel_url() {
    if [[ -f "$LOG_DIR/tunnel-output.log" ]]; then
        grep -o 'https://[^ ]*\.trycloudflare\.com' "$LOG_DIR/tunnel-output.log" 2>/dev/null | tail -1
    fi
}

get_local_port() {
    if [[ -f "$LOG_DIR/tunnel-output.log" ]]; then
        grep -o 'localhost:[0-9]*' "$LOG_DIR/tunnel-output.log" 2>/dev/null | head -1 | cut -d: -f2
    fi
}

get_log_size() {
    if [[ -d "$LOG_DIR" ]]; then
        du -sh "$LOG_DIR" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# 生成 HTML 页面
generate_html() {
    local status=$(get_status)
    local status_arr=(${status//|/ })
    local status_text=${status_arr[0]}
    local pid=${status_arr[1]}
    local uptime=${status_arr[2]}
    local mem=${status_arr[3]}
    
    local url=$(get_tunnel_url)
    local local_port=$(get_local_port)
    local log_size=$(get_log_size)
    
    if [[ "$status_text" == "running" ]]; then
        local status_color="#28a745"
        local status_display="🟢 运行中"
    else
        local status_color="#dc3545"
        local status_display="🔴 已停止"
    fi
    
    cat << EOF
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8

<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cloudflare Tunnel 监控</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            color: #333;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        header {
            background: white;
            border-radius: 15px;
            padding: 30px;
            text-align: center;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        h1 { color: #667eea; margin-bottom: 10px; }
        .status-badge {
            display: inline-block;
            padding: 10px 25px;
            border-radius: 25px;
            color: white;
            font-weight: bold;
            font-size: 1.2em;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        .info-card {
            background: white;
            padding: 20px;
            border-radius: 12px;
            text-align: center;
        }
        .info-card h3 {
            color: #666;
            font-size: 0.9em;
            margin-bottom: 8px;
        }
        .info-card .value {
            color: #333;
            font-size: 1.3em;
            font-weight: bold;
        }
        .url-section {
            background: white;
            border-radius: 15px;
            padding: 25px;
            margin: 20px 0;
            text-align: center;
        }
        .url-section h3 { margin-bottom: 15px; color: #333; }
        .url-display {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            font-size: 1.4em;
            color: #667eea;
            word-break: break-all;
            cursor: pointer;
        }
        .url-display:hover { background: #e9ecef; }
        .btn-group {
            margin-top: 20px;
            display: flex;
            gap: 10px;
            justify-content: center;
            flex-wrap: wrap;
        }
        .btn {
            padding: 12px 30px;
            border: none;
            border-radius: 8px;
            font-size: 1em;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
        }
        .btn-primary { background: #667eea; color: white; }
        .btn-danger { background: #dc3545; color: white; }
        .btn:hover { opacity: 0.9; }
        .logs {
            background: white;
            border-radius: 15px;
            padding: 20px;
            margin-top: 20px;
        }
        .logs h3 { margin-bottom: 15px; }
        .log-content {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 15px;
            border-radius: 8px;
            max-height: 300px;
            overflow-y: auto;
            font-family: monospace;
            font-size: 0.85em;
            white-space: pre-wrap;
            word-break: break-all;
        }
    </style>
    <meta http-equiv="refresh" content="5">
</head>
<body>
    <div class="container">
        <header>
            <h1>🚀 Cloudflare Tunnel 监控</h1>
            <div class="status-badge" style="background: $status_color;">
                $status_display
            </div>
        </header>
        
        <div class="info-grid">
            <div class="info-card">
                <h3>PID</h3>
                <div class="value">$pid</div>
            </div>
            <div class="info-card">
                <h3>运行时间</h3>
                <div class="value">$uptime</div>
            </div>
            <div class="info-card">
                <h3>内存使用</h3>
                <div class="value">$mem</div>
            </div>
            <div class="info-card">
                <h3>本地端口</h3>
                <div class="value">$local_port</div>
            </div>
            <div class="info-card">
                <h3>日志大小</h3>
                <div class="value">$log_size</div>
            </div>
        </div>
        
        <div class="url-section">
            <h3>🌐 当前隧道链接</h3>
            <div class="url-display" onclick="copyUrl()">
                ${url:-"暂无链接"}
            </div>
            <div class="btn-group">
                <a href="/restart" class="btn btn-primary">🔄 重启隧道</a>
                <a href="/stop" class="btn btn-danger">⏹ 停止隧道</a>
            </div>
        </div>
        
        <div class="logs">
            <h3>📋 最近日志</h3>
            <div class="log-content">$(tail -50 "$LOG_DIR/tunnel-output.log" 2>/dev/null || echo "暂无日志")</div>
        </div>
    </div>
    
    <script>
        function copyUrl() {
            const url = document.querySelector('.url-display').textContent.trim();
            if (url && url !== '暂无链接') {
                navigator.clipboard.writeText(url);
                alert('链接已复制到剪贴板!');
            }
        }
    </script>
</body>
</html>
EOF
}

# 处理请求
handle_request() {
    local path=$1
    
    case $path in
        "/restart")
            pkill -f "cloudflared tunnel" 2>/dev/null || true
            sleep 2
            cd /workspace/cloudflare-tunnel-optimized
            ./scripts/start-quick.sh 8080 > /dev/null 2>&1 &
            echo "HTTP/1.1 302 Redirect
Location: /

"
            ;;
        "/stop")
            pkill -f "cloudflared tunnel" 2>/dev/null || true
            rm -f "$PID_FILE"
            echo "HTTP/1.1 302 Redirect
Location: /

"
            ;;
        *)
            generate_html
            ;;
    esac
}

# 启动服务器
echo "╔══════════════════════════════════════════════════════╗"
echo "║     Cloudflare Tunnel Web 监控服务器                  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "访问地址: http://localhost:$PORT"
echo "按 Ctrl+C 停止"
echo ""

# 使用 socat 或 nc 创建简单 HTTP 服务器
while true; do
    # 读取请求
    REQUEST=$(head -1)
    
    if [[ -n "$REQUEST" ]]; then
        PATH=$(echo "$REQUEST" | cut -d' ' -f2)
        handle_request "$PATH"
    fi
done | timeout 86400 socat - TCP-LISTEN:$PORT,fork,crlf 2>/dev/null || true
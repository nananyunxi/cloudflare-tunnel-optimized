#!/usr/bin/env python3
"""
Cloudflare Tunnel 优化版 - Web 监控服务器
提供 Web 界面监控隧道状态、重启、停止功能
"""

import os
import sys
import signal
import subprocess
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

# 配置
PORT = int(os.environ.get('MONITOR_PORT', '9090'))
LOG_DIR = os.path.expanduser('~/.cloudflared/logs')
PID_FILE = os.path.expanduser('~/.cloudflared/tunnel.pid')

def get_status():
    """获取隧道状态"""
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, 'r') as f:
                pid = int(f.read().strip())
            # 检查进程是否存在
            try:
                os.kill(pid, 0)
                # 获取运行时间
                result = subprocess.run(['ps', '-o', 'etime=', '-p', str(pid)], 
                                      capture_output=True, text=True)
                uptime = result.stdout.strip() or 'N/A'
                # 获取内存
                result = subprocess.run(['ps', '-o', 'rss=', '-p', str(pid)], 
                                      capture_output=True, text=True)
                mem_kb = result.stdout.strip() or '0'
                mem_mb = f"{int(mem_kb) / 1024:.1f} MB"
                return {'status': 'running', 'pid': pid, 'uptime': uptime, 'mem': mem_mb}
            except (ProcessLookupError, PermissionError):
                pass
        except (ValueError, IOError):
            pass
    return {'status': 'stopped', 'pid': '-', 'uptime': '-', 'mem': '-'}

def get_tunnel_url():
    """获取隧道 URL"""
    log_file = os.path.join(LOG_DIR, 'tunnel-output.log')
    if os.path.exists(log_file):
        try:
            with open(log_file, 'r') as f:
                content = f.read()
            import re
            match = re.search(r'https://[^\s]+\.trycloudflare\.com', content)
            if match:
                return match.group(0)
        except:
            pass
    return None

def get_local_port():
    """获取本地端口"""
    log_file = os.path.join(LOG_DIR, 'tunnel-output.log')
    if os.path.exists(log_file):
        try:
            with open(log_file, 'r') as f:
                content = f.read()
            import re
            match = re.search(r'localhost:(\d+)', content)
            if match:
                return match.group(1)
        except:
            pass
    return '8080'

def get_log_content():
    """获取日志内容"""
    log_file = os.path.join(LOG_DIR, 'tunnel-output.log')
    if os.path.exists(log_file):
        try:
            with open(log_file, 'r') as f:
                lines = f.readlines()
                return ''.join(lines[-50:])
        except:
            pass
    return '暂无日志'

def get_log_size():
    """获取日志大小"""
    if os.path.exists(LOG_DIR):
        result = subprocess.run(['du', '-sh', LOG_DIR], capture_output=True, text=True)
        return result.stdout.split()[0] if result.stdout else '0'
    return '0'

def restart_tunnel():
    """重启隧道"""
    subprocess.run(['pkill', '-f', 'cloudflared tunnel'], stderr=subprocess.DEVNULL)
    time.sleep(2)
    script_path = os.path.join(os.path.dirname(__file__), 'start-quick.sh')
    if os.path.exists(script_path):
        subprocess.Popen([script_path, '8080'], 
                       stdout=subprocess.DEVNULL, 
                       stderr=subprocess.DEVNULL)

def stop_tunnel():
    """停止隧道"""
    subprocess.run(['pkill', '-f', 'cloudflared tunnel'], stderr=subprocess.DEVNULL)
    if os.path.exists(PID_FILE):
        os.remove(PID_FILE)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        
        if path == '/restart':
            restart_tunnel()
            self.send_response(302)
            self.send_header('Location', '/')
            self.end_headers()
            return
        
        if path == '/stop':
            stop_tunnel()
            self.send_response(302)
            self.send_header('Location', '/')
            self.end_headers()
            return
        
        # 获取状态
        status = get_status()
        url = get_tunnel_url()
        local_port = get_local_port()
        log_size = get_log_size()
        log_content = get_log_content()
        
        status_color = '#28a745' if status['status'] == 'running' else '#dc3545'
        status_text = '🟢 运行中' if status['status'] == 'running' else '🔴 已停止'
        url_display = url if url else '暂无链接'
        
        html = f'''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cloudflare Tunnel 监控</title>
    <meta http-equiv="refresh" content="5">
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            color: #333;
            padding: 20px;
        }}
        .container {{ max-width: 800px; margin: 0 auto; }}
        header {{
            background: white;
            border-radius: 15px;
            padding: 30px;
            text-align: center;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }}
        h1 {{ color: #667eea; margin-bottom: 10px; }}
        .status-badge {{
            display: inline-block;
            padding: 10px 25px;
            border-radius: 25px;
            color: white;
            font-weight: bold;
            font-size: 1.2em;
            background: {status_color};
        }}
        .info-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }}
        .info-card {{
            background: white;
            padding: 20px;
            border-radius: 12px;
            text-align: center;
        }}
        .info-card h3 {{ color: #666; font-size: 0.85em; margin-bottom: 8px; }}
        .info-card .value {{ color: #333; font-size: 1.2em; font-weight: bold; }}
        .url-section {{
            background: white;
            border-radius: 15px;
            padding: 25px;
            margin: 20px 0;
        }}
        .url-section h3 {{ margin-bottom: 15px; text-align: center; }}
        .url-display {{
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            font-size: 1.3em;
            color: #667eea;
            word-break: break-all;
            text-align: center;
            cursor: pointer;
        }}
        .btn-group {{
            margin-top: 20px;
            display: flex;
            gap: 10px;
            justify-content: center;
        }}
        .btn {{
            padding: 12px 30px;
            border: none;
            border-radius: 8px;
            font-size: 1em;
            cursor: pointer;
            text-decoration: none;
        }}
        .btn-primary {{ background: #667eea; color: white; }}
        .btn-danger {{ background: #dc3545; color: white; }}
        .logs {{
            background: white;
            border-radius: 15px;
            padding: 20px;
            margin-top: 20px;
        }}
        .log-content {{
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 15px;
            border-radius: 8px;
            max-height: 300px;
            overflow-y: auto;
            font-family: monospace;
            font-size: 0.8em;
            white-space: pre-wrap;
            word-break: break-all;
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🚀 Cloudflare Tunnel 监控</h1>
            <div class="status-badge">{status_text}</div>
        </header>
        
        <div class="info-grid">
            <div class="info-card">
                <h3>PID</h3>
                <div class="value">{status['pid']}</div>
            </div>
            <div class="info-card">
                <h3>运行时间</h3>
                <div class="value">{status['uptime']}</div>
            </div>
            <div class="info-card">
                <h3>内存</h3>
                <div class="value">{status['mem']}</div>
            </div>
            <div class="info-card">
                <h3>本地端口</h3>
                <div class="value">{local_port}</div>
            </div>
            <div class="info-card">
                <h3>日志大小</h3>
                <div class="value">{log_size}</div>
            </div>
        </div>
        
        <div class="url-section">
            <h3>🌐 隧道链接</h3>
            <div class="url-display" onclick="copyUrl()">{url_display}</div>
            <div class="btn-group">
                <a href="/restart" class="btn btn-primary">🔄 重启</a>
                <a href="/stop" class="btn btn-danger">⏹ 停止</a>
            </div>
        </div>
        
        <div class="logs">
            <h3>📋 最近日志</h3>
            <div class="log-content">{log_content}</div>
        </div>
    </div>
    
    <script>
    function copyUrl() {{
        const url = document.querySelector('.url-display').textContent.trim();
        if (url && url !== '暂无链接') {{
            navigator.clipboard.writeText(url);
            alert('链接已复制!');
        }}
    }}
    </script>
</body>
</html>'''
        
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(html.encode('utf-8'))
    
    def log_message(self, format, *args):
        pass  # 禁用日志

def main():
    print('╔══════════════════════════════════════════════════════╗')
    print('║     Cloudflare Tunnel Web 监控服务器                   ║')
    print('╚══════════════════════════════════════════════════════╝')
    print('')
    print(f'访问地址: http://localhost:{PORT}')
    print('按 Ctrl+C 停止')
    print('')
    
    server = HTTPServer(('0.0.0.0', PORT), Handler)
    
    def signal_handler(sig, frame):
        print('\n正在停止服务器...')
        server.shutdown()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass

if __name__ == '__main__':
    main()
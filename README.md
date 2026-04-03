# Cloudflare Tunnel 优化版

🚀 **智能内网穿透工具 - 基于 Cloudflare Tunnel 的优化封装**

完全免费、无需公网 IP、支持自定义域名、企业级安全保障。

---

## 📖 项目简介

本项目是对 Cloudflare Tunnel 官方工具 `cloudflared` 的**优化封装**，提供：

- **一键安装启动脚本**：跨平台支持（macOS/Linux/Windows）
- **自动重连守护进程**：断线自动重启，实时通知新链接
- **Web 监控界面**：状态查看、远程重启、链接复制
- **简化的使用体验**：交互式引导，无需记忆复杂命令

> **为什么选择本项目？**
> 
> 官方工具功能强大但使用门槛较高，且没有自动重连和监控功能。本项目添加了这些真正有用的优化。

---

## ✨ 核心特点

| 特性 | 说明 |
|------|------|
| **完全免费** | 无时长限制、无流量限制、无限隧道数量 |
| **自定义域名** | 支持绑定自己的域名，自动配置 HTTPS |
| **自动重连** | 断线自动检测并重启，通知用户新链接 |
| **Web 监控** | 浏览器查看状态、重启、停止、复制链接 |
| **一键启动** | 跨平台脚本，自动检测安装依赖 |

---

## 🔧 项目优化说明

### 优化一：跨平台一键安装启动脚本

官方工具需要用户手动下载安装、记忆命令行参数。本项目提供：

| 脚本文件 | 功能 | 适用平台 |
|---------|------|---------|
| `start-quick.sh` | 快速隧道一键启动 | macOS / Linux |
| `start-quick.bat` | 快速隧道一键启动 | Windows |
| `start-named.sh` | 命名隧道一键配置启动 | macOS / Linux |
| `start-named.bat` | 命名隧道一键配置启动 | Windows |
| `stop.sh` | 停止隧道服务 | macOS / Linux |
| `stop.bat` | 停止隧道服务 | Windows |

**脚本功能：**
- ✅ 自动检测系统架构 (amd64/arm64)
- ✅ 自动安装 cloudflared（如未安装）
- ✅ 交互式引导输入配置
- ✅ 后台运行，关闭终端不影响服务
- ✅ 显示隧道 URL 和连接信息

### 优化二：自动重连守护进程 🚀 新增

**官方没有的功能！** 当隧道意外断开时，自动检测并重新连接。

```bash
# 启动自动重连守护进程
./scripts/auto-reconnect.sh [端口]
```

**功能：**
- 每 30 秒检查隧道状态
- 检测到断开后自动重启
- **重启后在终端显示新的隧道链接**
- 保存最新链接到文件供其他程序读取

### 优化三：Web 监控界面 🚀 新增

**官方没有的功能！** 通过浏览器监控隧道状态。

```bash
# 启动 Web 监控服务器
python3 scripts/monitor.py
# 或使用 bash 版本
./scripts/monitor.sh
```

**功能：**
- 实时显示 PID、运行时间、内存使用
- **一键复制隧道链接**
- 远程重启/停止隧道
- 查看最近日志
- 自动刷新（5秒）

### 优化四：状态检查与更新

```bash
# 查看隧道状态
./scripts/status.sh

# 检查更新
./scripts/update.sh
```

**配置文件优化示例：**
```yaml
originRequest:
  connectTimeout: 30s      # 连接超时 30 秒
  tcpKeepAlive: 30s        # TCP 保活 30 秒
  keepAliveConnections: 100  # 连接池大小
  http2Origin: true        # 启用 HTTP/2 提升性能
```

### 优化四：后台运行支持

**问题背景：**
官方工具默认前台运行，关闭终端会导致隧道中断。

**优化方案：**
脚本使用 `nohup` + 后台运行，关闭终端窗口不影响服务：

```bash
# macOS/Linux
nohup cloudflared tunnel run my-tunnel > tunnel.log 2>&1 &

# Windows
start /b cloudflared tunnel run my-tunnel
```

### 优化五：完善的配置模板

提供 `config.example.yml` 配置模板，包含：
- 多子域名配置示例
- SSH/RDP 等非 HTTP 协议示例
- 连接优化参数示例

---

## 📋 目录

- [工作原理](#工作原理)
- [安装使用](#安装使用)
- [运行模式](#运行模式)
- [配置说明](#配置说明)
- [常见问题](#常见问题)

---

## 🔧 工作原理

### 技术架构

```
┌─────────────┐      ┌──────────────────┐      ┌─────────────┐
│  本地服务    │ ←──→ │  cloudflared     │ ←──→ │ Cloudflare  │
│  (内网)     │      │  (加密隧道)       │      │  边缘节点   │
└─────────────┘      └──────────────────┘      └─────────────┘
                                                      ↑
                                                      │
                                                 互联网用户
```

### 核心原理

1. **出站仅连接（Outbound-only）**
   - 无需开放任何入站端口
   - 通过 cloudflared 主动连接 Cloudflare 边缘节点
   - 完美解决 NAT 穿透问题

2. **加密传输**
   - 所有数据通过 TLS 加密
   - 端到端安全传输

3. **全球加速**
   - 利用 Cloudflare 全球 Anycast 网络
   - 自动选择最近边缘节点

### 与其他方案对比

| 对比项 | Cloudflare Tunnel | ngrok | frp | tunnelto |
|--------|-------------------|-------|-----|----------|
| 需要公网 IP | ❌ 不需要 | ❌ 不需要 | ✅ 需要 | ❌ 不需要 |
| 需要云服务器 | ❌ 不需要 | ❌ 不需要 | ✅ 需要 | ❌ 不需要 |
| 免费使用 | ✅ 完全免费 | ⚠️ 有限制 | ✅ 免费 | ⚠️ 试用短 |
| 自定义域名 | ✅ 免费支持 | 💰 付费 | ✅ 支持 | 💰 付费 |
| HTTPS | ✅ 自动配置 | ✅ 自动配置 | ⚠️ 需配置 | ✅ 自动配置 |
| DDoS 防护 | ✅ 自带 | ❌ 无 | ❌ 无 | ❌ 无 |
| 全球加速 | ✅ 全球节点 | ⚠️ 有限 | ❌ 无 | ⚠️ 有限 |

---

## 🚀 安装使用

### 方式一：使用启动脚本（推荐）

#### macOS / Linux

```bash
# 快速隧道模式（无需注册）
./scripts/start-quick.sh [端口号]

# 命名隧道模式（支持自定义域名）
./scripts/start-named.sh

# 停止隧道
./scripts/stop.sh
```

#### Windows

```powershell
# 快速隧道模式
.\scripts\start-quick.bat [端口号]

# 命名隧道模式
.\scripts\start-named.bat

# 停止隧道
.\scripts\stop.bat
```

### 方式二：手动安装

#### macOS

```bash
# Homebrew 安装
brew install cloudflared

# 或下载二进制文件
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

#### Linux

```bash
# Debian/Ubuntu
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb

# 或直接下载二进制
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

#### Windows

1. 下载 [cloudflared-windows-amd64.exe](https://github.com/cloudflare/cloudflared/releases/latest)
2. 重命名为 `cloudflared.exe`
3. 放入系统 PATH 目录

---

## 🎯 运行模式

### 模式一：快速隧道（Quick Tunnel）

**无需注册，即开即用**

```bash
# 暴露本地 8080 端口
cloudflared tunnel --url http://localhost:8080
```

生成的随机域名：`https://xxx-xxx-xxx.trycloudflare.com`

**特点：**
- ✅ 无需账号
- ✅ 即开即用
- ❌ 域名随机
- ❌ 会话结束域名失效

---

### 模式二：命名隧道（Named Tunnel）

**需要 Cloudflare 账号，域名固定**

```bash
# 1. 登录 Cloudflare
cloudflared tunnel login

# 2. 创建隧道
cloudflared tunnel create my-tunnel

# 3. 配置路由
cloudflared tunnel route dns my-tunnel myapp

# 4. 运行隧道
cloudflared tunnel run my-tunnel
```

**特点：**
- ✅ 域名固定
- ✅ 可管理多个隧道
- ⚠️ 需要 Cloudflare 账号

---

## 🔧 管理命令

### 状态检查

查看隧道运行状态、版本、内存使用等信息：

```bash
# macOS / Linux
./scripts/status.sh

# Windows
.\scripts\status.bat
```

**输出示例：**
```
【程序状态】
  cloudflared: 已安装
  版本: cloudflared version 2026.3.0

【隧道状态】
  状态: 运行中
  PID: 12345
  运行时间: 1:23:45
  内存使用: 45.2 MB

【隧道信息】
  公网地址: https://xxx.trycloudflare.com
```

### 更新检查

检查并更新 cloudflared 到最新版本：

```bash
# macOS / Linux
./scripts/update.sh

# Windows
.\scripts\update.bat
```

### 停止隧道

```bash
# macOS / Linux
./scripts/stop.sh

# Windows
.\scripts\stop.bat
```

---

### 模式三：自定义域名（推荐）

**绑定自己的域名，专业可靠**

#### 步骤 1：添加域名到 Cloudflare

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 点击「添加站点」
3. 输入你的域名
4. 选择**免费套餐**
5. 修改域名的 NS 服务器为 Cloudflare 提供的地址

#### 步骤 2：创建隧道

```bash
# 登录授权
cloudflared tunnel login

# 创建隧道
cloudflared tunnel create my-tunnel
```

#### 步骤 3：创建配置文件

创建 `~/.cloudflared/config.yml`：

```yaml
tunnel: my-tunnel
credentials-file: ~/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: app.yourdomain.com
    service: http://localhost:8080
  - hostname: api.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
```

#### 步骤 4：绑定域名

```bash
cloudflared tunnel route dns my-tunnel app.yourdomain.com
```

#### 步骤 5：运行

```bash
cloudflared tunnel run my-tunnel
```

**特点：**
- ✅ 使用自己的域名
- ✅ 支持 HTTPS 自动配置
- ✅ 可绑定多个子域名
- ✅ 免费 DDoS 防护

---

## ⚙️ 配置说明

### 完整配置文件示例

```yaml
# ~/.cloudflared/config.yml

# 隧道名称或 ID
tunnel: my-tunnel

# 凭证文件路径
credentials-file: ~/.cloudflared/<tunnel-id>.json

# 入口规则配置
ingress:
  # 规则 1: Web 应用
  - hostname: web.yourdomain.com
    service: http://localhost:8080
    originRequest:
      connectTimeout: 30s
      tcpKeepAlive: 30s
      noTLSVerify: true
      http2Origin: true

  # 规则 2: API 服务
  - hostname: api.yourdomain.com
    service: http://localhost:3000

  # 规则 3: SSH 访问
  - hostname: ssh.yourdomain.com
    service: ssh://localhost:22

  # 默认规则（必须）
  - service: http_status:404
```

---

## ❓ 常见问题

### Q1: 快速隧道的域名会变吗？

是的，Quick Tunnel 生成的域名是临时的，每次启动都会变化。如需固定域名，请使用命名隧道或自定义域名模式。

### Q2: 免费版本有什么限制？

- ✅ 无限隧道数量
- ✅ 无限流量
- ✅ 自定义域名
- ✅ DDoS 防护
- ⚠️ Zero Trust 免费用户限制 50 人

### Q3: 访问速度慢怎么办？

1. 使用 `--protocol h2mux` 参数
2. 检查本地网络连接
3. 尝试使用 Cloudflare WARP 客户端

### Q4: 如何查看日志？

```bash
# 实时日志
cloudflared tunnel run --loglevel debug my-tunnel

# 保存日志到文件
cloudflared tunnel run --logfile tunnel.log my-tunnel
```

### Q5: 如何停止隧道？

```bash
# 使用脚本
./scripts/stop.sh

# 或手动
pkill cloudflared  # Linux/macOS
taskkill /F /IM cloudflared.exe  # Windows
```

---

## 📁 项目结构

```
cloudflare-tunnel-optimized/
├── README.md                 # 项目文档
├── config.example.yml        # 配置文件示例
├── .gitignore               # Git 忽略文件
└── scripts/
    ├── start-quick.sh       # 快速隧道启动
    ├── start-quick.bat      # Windows 快速隧道启动
    ├── start-named.sh       # 命名隧道启动
    ├── start-named.bat      # Windows 命名隧道启动
    ├── stop.sh              # 停止隧道
    ├── stop.bat             # Windows 停止
    ├── status.sh            # 状态检查
    ├── status.bat           # Windows 状态检查
    ├── update.sh            # 更新检查
    ├── update.bat           # Windows 更新检查
    ├── auto-reconnect.sh    # 自动重连守护进程 🚀
    ├── monitor.py           # Web 监控服务器 🚀
    └── monitor.sh           # Web 监控 (Bash版) 🚀
```

---

## 📜 开源协议

本项目采用 MIT 协议开源。

Cloudflare Tunnel 由 Cloudflare Inc. 提供，[cloudflared 客户端](https://github.com/cloudflare/cloudflared) 同样采用 MIT 协议。

---

## 🙏 致谢

- [Cloudflare](https://www.cloudflare.com/) - 提供免费的 Tunnel 服务
- [cloudflared](https://github.com/cloudflare/cloudflared) - 开源客户端

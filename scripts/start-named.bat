@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM #######################################################
REM Cloudflare Tunnel 优化版 - 命名隧道启动脚本 (Windows)
REM 需要登录 Cloudflare 账号
REM 支持自定义域名
REM #######################################################

set CONFIG_DIR=%USERPROFILE%\.cloudflared
set CONFIG_FILE=%CONFIG_DIR%\config.yml
set LOG_DIR=%CONFIG_DIR%\logs
set PID_FILE=%CONFIG_DIR%\tunnel.pid

REM 打印横幅
echo.
echo ╔══════════════════════════════════════════════════════╗
echo ║     Cloudflare Tunnel 优化版 - 命名隧道启动脚本       ║
echo ║       支持自定义域名 · 固定隧道 · 企业级安全           ║
echo ╚══════════════════════════════════════════════════════╝
echo.

REM 检查 cloudflared
where cloudflared >nul 2>&1
if %errorlevel% neq 0 (
    echo [警告] cloudflared 未安装
    echo 请先运行 start-quick.bat 安装 cloudflared
    pause
    exit /b 1
)

REM 创建目录
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM 检查登录状态
if not exist "%CONFIG_DIR%\cert.pem" (
    echo [提示] 尚未登录 Cloudflare
    echo 即将打开浏览器进行授权，请在浏览器中选择域名并授权...
    echo.
    cloudflared tunnel login
    if !errorlevel! neq 0 (
        echo [错误] 登录失败
        pause
        exit /b 1
    )
    echo [✓] 登录成功
) else (
    echo [✓] 已登录 Cloudflare
)

echo.
echo 现有隧道列表:
echo ══════════════════════════════════════════════════════
cloudflared tunnel list
echo ══════════════════════════════════════════════════════
echo.

echo 请选择操作:
echo   1) 使用现有隧道
echo   2) 创建新隧道
echo.
set /p CHOICE="请输入选项 [1/2]: "

if "%CHOICE%"=="1" (
    set /p TUNNEL_NAME="请输入隧道名称: "
    goto :start_tunnel
)

if "%CHOICE%"=="2" (
    set /p TUNNEL_NAME="请输入新隧道名称 (仅字母、数字、连字符): "
    
    echo 正在创建隧道: !TUNNEL_NAME! ...
    cloudflared tunnel create "!TUNNEL_NAME!"
    if !errorlevel! neq 0 (
        echo [错误] 隧道创建失败
        pause
        exit /b 1
    )
    echo [✓] 隧道创建成功
    
    REM 配置隧道
    echo.
    echo ══════════════════════════════════════════════════════
    echo 配置隧道路由
    echo ══════════════════════════════════════════════════════
    
    set /p SUBDOMAIN="请输入子域名 (如: app, api, www): "
    set /p DOMAIN="请输入域名 (如: yourdomain.com): "
    set /p LOCAL_PORT="请输入本地服务端口 [默认: 8080]: "
    if "!LOCAL_PORT!"=="" set LOCAL_PORT=8080
    
    set FULL_HOSTNAME=!SUBDOMAIN!.!DOMAIN!
    
    echo 正在配置 DNS 路由: !FULL_HOSTNAME!
    cloudflared tunnel route dns "!TUNNEL_NAME!" "!FULL_HOSTNAME!"
    
    REM 获取隧道 ID
    for /f "tokens=1" %%i in ('cloudflared tunnel list ^| findstr "!TUNNEL_NAME!"') do set TUNNEL_ID=%%i
    
    REM 创建配置文件
    (
        echo # Cloudflare Tunnel 配置文件
        echo tunnel: !TUNNEL_NAME!
        echo credentials-file: %CONFIG_DIR%\!TUNNEL_ID!.json
        echo.
        echo ingress:
        echo   - hostname: !FULL_HOSTNAME!
        echo     service: http://localhost:!LOCAL_PORT!
        echo     originRequest:
        echo       connectTimeout: 30s
        echo       tcpKeepAlive: 30s
        echo       noTLSVerify: true
        echo.
        echo   - service: http_status:404
    ) > "%CONFIG_FILE%"
    
    echo [✓] 配置文件已创建: %CONFIG_FILE%
    echo [✓] DNS 路由已配置: https://!FULL_HOSTNAME!
    
    goto :start_tunnel
)

echo [错误] 无效选项
pause
exit /b 1

:start_tunnel
REM 检查是否已有隧道在运行
if exist "%PID_FILE%" (
    set /p OLD_PID=<"%PID_FILE%"
    tasklist /FI "PID eq !OLD_PID!" 2>nul | findstr "!OLD_PID!" >nul
    if !errorlevel! equ 0 (
        echo [警告] 已有隧道在运行
        set /p RESTART="是否停止并重启? [Y/n]: "
        if /i not "!RESTART!"=="n" (
            taskkill /PID !OLD_PID! /F >nul 2>&1
            del "%PID_FILE%" >nul 2>&1
        )
    )
)

echo.
echo 正在启动隧道: %TUNNEL_NAME% ...

start /b cloudflared tunnel run --config "%CONFIG_FILE%" --edge-ip-version auto --retries 5 > "%LOG_DIR%\tunnel.log" 2>&1

for /f "tokens=2" %%i in ('tasklist /FI "IMAGENAME eq cloudflared.exe" /FO LIST ^| findstr "PID:"') do set PID=%%i

if defined PID echo !PID! > "%PID_FILE%"

timeout /t 3 >nul

echo.
echo ══════════════════════════════════════════════════════
echo [✓] 隧道启动成功！
echo ══════════════════════════════════════════════════════
echo.
echo 隧道信息:
echo   隧道名称: %TUNNEL_NAME%
if defined PID echo   隧道 PID: %PID%
echo   配置文件: %CONFIG_FILE%
echo   日志文件: %LOG_DIR%\tunnel.log
echo.
echo 提示:
echo   - 使用 stop.bat 停止隧道
echo   - 编辑 %CONFIG_FILE% 添加更多服务
echo.
pause

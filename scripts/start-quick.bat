@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM #######################################################
REM Cloudflare Tunnel 优化版 - 快速隧道启动脚本 (Windows)
REM 无需注册，即开即用
REM #######################################################

set DEFAULT_PORT=8080
set CONFIG_DIR=%USERPROFILE%\.cloudflared
set LOG_DIR=%CONFIG_DIR%\logs
set PID_FILE=%CONFIG_DIR%\tunnel.pid

REM 打印横幅
echo.
echo ╔══════════════════════════════════════════════════════╗
echo ║     Cloudflare Tunnel 优化版 - 快速隧道启动脚本       ║
echo ║          免费 · 稳定 · 无需注册 · 即开即用            ║
echo ╚══════════════════════════════════════════════════════╝
echo.

REM 检查 cloudflared 是否已安装
where cloudflared >nul 2>&1
if %errorlevel% neq 0 (
    echo [警告] cloudflared 未安装
    echo.
    call :install_cloudflared
) else (
    for /f "tokens=*" %%i in ('cloudflared --version 2^>^&1') do (
        echo [✓] cloudflared 已安装: %%i
        goto :version_done
    )
    :version_done
)

REM 创建必要的目录
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM 获取端口
set PORT=%1
if "%PORT%"=="" (
    set /p PORT="请输入要暴露的本地端口 [默认: %DEFAULT_PORT%]: "
)
if "%PORT%"=="" set PORT=%DEFAULT_PORT%

echo.
echo ══════════════════════════════════════════════════════
echo 启动参数配置
echo ══════════════════════════════════════════════════════
echo 本地端口: %PORT%
echo.

REM 检查端口是否有服务监听
netstat -ano | findstr ":%PORT% " | findstr "LISTENING" >nul
if %errorlevel% neq 0 (
    echo [警告] 本地端口 %PORT% 没有服务在监听
    set /p CONTINUE="是否继续启动隧道? [Y/n]: "
    if /i "!CONTINUE!"=="n" (
        echo 已取消
        exit /b 0
    )
) else (
    echo [✓] 本地端口 %PORT% 已有服务在监听
)

REM 检查是否已有隧道在运行
if exist "%PID_FILE%" (
    set /p OLD_PID=<"%PID_FILE%"
    tasklist /FI "PID eq !OLD_PID!" 2>nul | findstr "!OLD_PID!" >nul
    if !errorlevel! equ 0 (
        echo [警告] 已有隧道在运行 (PID: !OLD_PID!)
        set /p RESTART="是否停止并重启? [Y/n]: "
        if /i not "!RESTART!"=="n" (
            taskkill /PID !OLD_PID! /F >nul 2>&1
            del "%PID_FILE%" >nul 2>&1
            timeout /t 2 >nul
        ) else (
            exit /b 0
        )
    ) else (
        del "%PID_FILE%" >nul 2>&1
    )
)

echo.
echo ══════════════════════════════════════════════════════
echo 正在启动 Cloudflare Tunnel...
echo ══════════════════════════════════════════════════════

REM 启动隧道
start /b cloudflared tunnel --url http://localhost:%PORT% --edge-ip-version auto --retries 5 --loglevel info > "%LOG_DIR%\tunnel.log" 2>&1

REM 获取进程 PID
for /f "tokens=2" %%i in ('tasklist /FI "IMAGENAME eq cloudflared.exe" /FO LIST ^| findstr "PID:"') do (
    set PID=%%i
)

if defined PID (
    echo !PID! > "%PID_FILE%"
)

REM 等待隧道建立
echo [等待] 正在等待隧道建立...
timeout /t 5 >nul

REM 从日志中提取隧道 URL
set TUNNEL_URL=
set ATTEMPT=0
:max_attempts
if !ATTEMPT! geq 30 goto :show_result

for /f "tokens=*" %%i in ('findstr /r "trycloudflare.com" "%LOG_DIR%\tunnel.log" 2^>nul ^| findstr /r "https://"') do (
    for %%a in (%%i) do (
        echo %%a | findstr "trycloudflare.com" >nul
        if !errorlevel! equ 0 (
            set TUNNEL_URL=%%a
            goto :show_result
        )
    )
)

set /a ATTEMPT+=1
timeout /t 1 >nul
goto :max_attempts

:show_result
echo.
echo ══════════════════════════════════════════════════════
echo [✓] Cloudflare Tunnel 启动成功！
echo ══════════════════════════════════════════════════════
echo.
echo 隧道信息:
echo   本地端口: %PORT%
if defined PID echo   隧道 PID: %PID%
if defined TUNNEL_URL echo   公网地址: %TUNNEL_URL%
echo.
echo 日志文件: %LOG_DIR%\tunnel.log
echo.
echo 提示:
echo   - 隧道正在后台运行，关闭此窗口不影响服务
echo   - 使用 stop.bat 停止隧道
echo.
echo ══════════════════════════════════════════════════════

pause
exit /b 0

:install_cloudflared
echo [安装] 正在安装 cloudflared...
echo.

REM 检测系统架构
set ARCH=amd64
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set ARCH=arm64

REM 下载 cloudflared
set DOWNLOAD_URL=https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-%ARCH%.exe
set INSTALL_PATH=%CONFIG_DIR%\cloudflared.exe

if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"

echo 正在下载: %DOWNLOAD_URL%
powershell -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%INSTALL_PATH%'"

if exist "%INSTALL_PATH%" (
    echo [✓] cloudflared 下载完成
    
    REM 添加到 PATH (当前会话)
    set PATH=%CONFIG_DIR%;%PATH%
    
    REM 提示用户添加到系统 PATH
    echo.
    echo [提示] 请将以下目录添加到系统 PATH 环境变量:
    echo   %CONFIG_DIR%
    echo.
    echo 或者手动将 cloudflared.exe 移动到已在 PATH 中的目录。
    echo.
) else (
    echo [错误] cloudflared 下载失败
    echo 请手动下载: https://github.com/cloudflare/cloudflared/releases
    pause
    exit /b 1
)

exit /b 0

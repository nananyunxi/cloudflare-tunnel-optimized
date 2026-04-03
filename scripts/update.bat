@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM #######################################################
REM Cloudflare Tunnel 优化版 - 更新检查脚本 (Windows)
REM #######################################################

echo.
echo ══════════════════════════════════════════════════════
echo         Cloudflare Tunnel 更新检查
echo ══════════════════════════════════════════════════════
echo.

REM 检查 cloudflared 是否安装
where cloudflared >nul 2>&1
if %errorlevel% neq 0 (
    echo cloudflared 未安装
    echo 请先运行 start-quick.bat 安装
    pause
    exit /b 1
)

REM 获取当前版本
for /f "tokens=3" %%i in ('cloudflared --version 2^>^&1') do set CURRENT_VERSION=%%i
echo 当前版本: %CURRENT_VERSION%
echo.

echo 正在检查最新版本...

REM 使用 PowerShell 获取最新版本
for /f "tokens=*" %%i in ('powershell -Command "(Invoke-WebRequest -Uri 'https://api.github.com/repos/cloudflare/cloudflared/releases/latest' -UseBasicParsing | ConvertFrom-Json).tag_name"') do set LATEST_VERSION=%%i

if "%LATEST_VERSION%"=="" (
    echo 无法获取最新版本信息
    echo 请手动检查: https://github.com/cloudflare/cloudflared/releases
    pause
    exit /b 0
)

REM 去掉 v 前缀
set LATEST_VERSION=%LATEST_VERSION:v=%

echo 最新版本: %LATEST_VERSION%
echo.

if "%CURRENT_VERSION%"=="%LATEST_VERSION%" (
    echo ✓ 已是最新版本
) else (
    echo 发现新版本!
    echo.
    set /p UPDATE="是否立即更新? [Y/n]: "
    
    if /i not "!UPDATE!"=="n" (
        echo.
        echo 正在更新 cloudflared...
        
        REM 检测架构
        set ARCH=amd64
        if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set ARCH=arm64
        
        set DOWNLOAD_URL=https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-%ARCH%.exe
        set INSTALL_PATH=%USERPROFILE%\.cloudflared\cloudflared.exe
        
        if not exist "%USERPROFILE%\.cloudflared" mkdir "%USERPROFILE%\.cloudflared"
        
        echo 下载中...
        powershell -Command "Invoke-WebRequest -Uri '!DOWNLOAD_URL!' -OutFile '!INSTALL_PATH!'"
        
        if exist "!INSTALL_PATH!" (
            echo.
            echo ✓ 更新完成!
            echo 请将 cloudflared.exe 所在目录添加到系统 PATH
            echo 目录: %USERPROFILE%\.cloudflared
        ) else (
            echo 更新失败，请手动下载
        )
    )
)

echo.
echo ══════════════════════════════════════════════════════
pause

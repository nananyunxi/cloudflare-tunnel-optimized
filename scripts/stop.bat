@echo off
chcp 65001 >nul

REM #######################################################
REM Cloudflare Tunnel 优化版 - 停止脚本 (Windows)
REM #######################################################

set PID_FILE=%USERPROFILE%\.cloudflared\tunnel.pid

echo 正在停止 Cloudflare Tunnel...

if exist "%PID_FILE%" (
    set /p PID=<"%PID_FILE%"
    
    tasklist /FI "PID eq %PID%" 2>nul | findstr "%PID%" >nul
    if %errorlevel% equ 0 (
        taskkill /PID %PID% /F >nul 2>&1
        del "%PID_FILE%" >nul 2>&1
        echo [✓] 隧道已停止 (PID: %PID%)
    ) else (
        del "%PID_FILE%" >nul 2>&1
        echo [提示] 隧道进程已不存在，清理 PID 文件
    )
) else (
    REM 尝试通过进程名查找
    tasklist /FI "IMAGENAME eq cloudflared.exe" 2>nul | findstr "cloudflared.exe" >nul
    if %errorlevel% equ 0 (
        taskkill /IM cloudflared.exe /F >nul 2>&1
        echo [✓] 所有 cloudflared 进程已停止
    ) else (
        echo [提示] 没有找到运行中的隧道
    )
)

echo.
pause

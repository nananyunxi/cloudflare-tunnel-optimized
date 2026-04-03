@echo off
chcp 65001 >nul

REM #######################################################
REM Cloudflare Tunnel 优化版 - 状态检查脚本 (Windows)
REM #######################################################

set PID_FILE=%USERPROFILE%\.cloudflared\tunnel.pid
set LOG_DIR=%USERPROFILE%\.cloudflared\logs

echo.
echo ══════════════════════════════════════════════════════
echo         Cloudflare Tunnel 状态检查
echo ══════════════════════════════════════════════════════
echo.

REM 检查 cloudflared 是否安装
echo 【程序状态】
where cloudflared >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('cloudflared --version 2^>^&1') do (
        echo   cloudflared: 已安装
        echo   版本: %%i
        goto :version_done
    )
    :version_done
) else (
    echo   cloudflared: 未安装
    exit /b 1
)

echo.

REM 检查隧道进程
echo 【隧道状态】
if exist "%PID_FILE%" (
    set /p PID=<"%PID_FILE%"
    
    tasklist /FI "PID eq !PID!" 2>nul | findstr "!PID!" >nul
    if !errorlevel! equ 0 (
        echo   状态: 运行中
        echo   PID: !PID!
    ) else (
        echo   状态: 已停止
        del "%PID_FILE%" >nul 2>&1
    )
) else (
    tasklist /FI "IMAGENAME eq cloudflared.exe" 2>nul | findstr "cloudflared.exe" >nul
    if !errorlevel! equ 0 (
        echo   状态: 运行中 ^(未通过脚本启动^)
    ) else (
        echo   状态: 未运行
    )
)

echo.

REM 检查隧道 URL
echo 【隧道信息】
if exist "%LOG_DIR%\tunnel-output.log" (
    for /f "tokens=*" %%i in ('findstr /r "trycloudflare.com" "%LOG_DIR%\tunnel-output.log" 2^>nul ^| findstr /r "https://"') do (
        for %%a in (%%i) do (
            echo %%a | findstr "trycloudflare.com" >nul
            if !errorlevel! equ 0 (
                echo   公网地址: %%a
                goto :url_found
            )
        )
    )
    :url_found
)

echo.

REM 检查日志
echo 【日志文件】
if exist "%LOG_DIR%" (
    echo   日志目录: %LOG_DIR%
    if exist "%LOG_DIR%\tunnel.log" (
        for %%A in ("%LOG_DIR%\tunnel.log") do echo   日志大小: %%~zA 字节
    )
) else (
    echo   日志目录: 不存在
)

echo.
echo ══════════════════════════════════════════════════════
pause

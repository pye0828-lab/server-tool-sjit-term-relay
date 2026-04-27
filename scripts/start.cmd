@echo off
:: start.cmd - Start the relay server using virtual environment
cd /d "%~dp0\.."

if not exist .venv (
    echo [ERROR] .venv not found. Run scripts\setup_venv.cmd first.
    pause
    exit /b 1
)

echo [INFO] Starting SJIT Term Relay Server...
echo [INFO] Press Ctrl+C to stop.
echo.
.venv\Scripts\python ws_relay_server.py %*
pause

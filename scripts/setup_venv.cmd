@echo off
:: setup_venv.cmd - Create virtual environment and install packages
cd /d "%~dp0\.."

echo [INFO] Checking Python...
python --version
if %errorlevel% neq 0 (
    echo [ERROR] Python not found. Install Python 3.10+ from https://www.python.org
    pause
    exit /b 1
)

if exist .venv (
    echo [WARN] .venv already exists.
    set /p ANSWER="Recreate? [y/N]: "
    if /i "%ANSWER%" neq "y" (
        echo [INFO] Cancelled.
        pause
        exit /b 0
    )
    echo [INFO] Removing existing .venv...
    rmdir /s /q .venv
)

echo [INFO] Creating virtual environment...
python -m venv .venv
if %errorlevel% neq 0 (
    echo [ERROR] Failed to create virtual environment.
    pause
    exit /b 1
)

echo [INFO] Installing packages...
.venv\Scripts\pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install packages.
    pause
    exit /b 1
)

echo.
echo [DONE] Setup complete. Run scripts\start.cmd to start the server.
pause

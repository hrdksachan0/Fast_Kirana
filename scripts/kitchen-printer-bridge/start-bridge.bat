@echo off
title FastKirana Kitchen Thermal Printer Bridge
cd /d "%~dp0"
color 0A

:LOOP
cls
echo ================================================================
echo       FASTKIRANA KITCHEN THERMAL PRINTER BRIDGE (1-CLICK)
echo ================================================================
echo.
echo [1/3] Checking Node.js environment...
where node >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo [ERROR] Node.js is not installed on this PC!
    echo Please install Node.js from https://nodejs.org/
    echo.
    pause
    exit /b
)

echo [2/3] Checking dependencies...
if not exist node_modules\@supabase\supabase-js (
    echo Installing Supabase library dependencies, please wait...
    call npm install @supabase/supabase-js --no-audit --no-fund
)

echo [3/3] Connecting to FastKirana Live Kitchen Channel...
echo.
echo ----------------------------------------------------------------
echo   PRINTER BRIDGE IS ACTIVE AND LISTENING FOR "SEND KOT" ORDERS
echo   Do not close this window while kitchen is open.
echo ----------------------------------------------------------------
echo.

node kitchen-printer-bridge.js

echo.
echo ================================================================
echo [WARNING] Printer Bridge disconnected or stopped.
echo Auto-restarting in 5 seconds... (Press Ctrl+C to stop)
echo ================================================================
timeout /t 5 /nobreak >nul
goto LOOP

@echo off
title FastKirana Kitchen Thermal Printer Bridge (Offline Resilient)
cd /d "%~dp0"
color 0A

:LOOP
cls
echo ================================================================
echo     FASTKIRANA KITCHEN THERMAL PRINTER BRIDGE (ROBUST EDITION)
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

echo [3/3] Starting FastKirana Robust Printer Engine...
echo.
echo ----------------------------------------------------------------
echo   PRINTER BRIDGE IS ACTIVE AND READY!
echo   - Persistent Database Queue : ACTIVE (Offline orders never lost)
echo   - Windows Keep-Awake        : ACTIVE (Laptop will not sleep)
echo   - Network Watchdog          : ACTIVE (Auto-reconnects on Wi-Fi drop)
echo ----------------------------------------------------------------
echo.

node kitchen-printer-bridge.js

echo.
echo ================================================================
echo [WARNING] Printer Bridge stopped or crashed.
echo Auto-restarting in 5 seconds... (Press Ctrl+C to exit)
echo ================================================================
timeout /t 5 /nobreak >nul
goto LOOP

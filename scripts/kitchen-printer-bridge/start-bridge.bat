@echo off
title FastKirana Kitchen Printer Bridge
cd /d "%~dp0"

echo ==================================================
echo   FastKirana Kitchen Printer Setup Bridge
echo ==================================================
echo Checking if Node.js is installed...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not installed on this PC!
    echo Please install Node.js from https://nodejs.org/ first.
    pause
    exit /b
)

if not exist node_modules (
    echo [Setup] Installing Supabase library dependencies...
    npm init -y >nul 2>&1
    npm install @supabase/supabase-js --no-audit --no-fund
)

echo Starting background printer listener...
node kitchen-printer-bridge.js
pause

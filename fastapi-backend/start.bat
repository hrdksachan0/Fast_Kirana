@echo off
echo ==========================================
echo   FastKirana FastAPI Backend Quick Start
echo ==========================================
echo.

if not exist "venv\Scripts\activate.bat" (
    echo [1/4] Creating virtual environment...
    python -m venv venv
    if errorlevel 1 (
        echo ERROR: Python not found. Install Python 3.11+ first.
        pause
        exit /b 1
    )
)

echo [2/4] Activating virtual environment...
call venv\Scripts\activate.bat

echo [3/4] Installing dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: pip install failed.
    pause
    exit /b 1
)

if not exist ".env" (
    echo [WARN] .env file not found. Copying from .env.example...
    copy .env.example .env
    echo Please edit .env with your DATABASE_URL and AUTH_SECRET
    pause
)

echo [4/4] Initializing database (optional)...
set /p INIT_DB="Do you want to initialize tables? (y/n): "
if /i "%INIT_DB%"=="y" (
    python init_db.py
)

echo.
echo ==========================================
echo   Starting FastAPI Server...
echo   Swagger docs: http://localhost:8000/docs
echo ==========================================
echo.

uvicorn main:app --reload --host 0.0.0.0 --port 8000

pause

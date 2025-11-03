@echo off
REM Automated virtual environment setup for Streaming Ingest project
REM Creates venv, activates it, installs dependencies, and runs checks

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."
set "VENV_NAME=streaming-ingest-example"
set "VENV_PATH=%PROJECT_ROOT%\%VENV_NAME%"

echo ============================================================================
echo Streaming Ingest: Automated Environment Setup
echo ============================================================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python not found
    echo    Please install Python 3.8+ from https://python.org
    exit /b 1
)

echo Step 1: Creating virtual environment '%VENV_NAME%'...
if exist "%VENV_PATH%" (
    echo    Virtual environment already exists at: %VENV_PATH%
    set /p "RECREATE=   Remove and recreate? (y/N): "
    if /i "!RECREATE!"=="y" (
        echo    Removing existing environment...
        rmdir /s /q "%VENV_PATH%"
        echo    Creating new environment...
        python -m venv "%VENV_PATH%"
        echo    Virtual environment created
    ) else (
        echo    Using existing environment
    )
) else (
    python -m venv "%VENV_PATH%"
    echo    Virtual environment created
)
echo.

echo Step 2: Activating virtual environment...
call "%VENV_PATH%\Scripts\activate.bat"
echo    Activated: %VIRTUAL_ENV%
echo.

echo Step 3: Upgrading pip...
python -m pip install --upgrade pip --quiet
echo    pip upgraded
echo.

echo Step 4: Installing project dependencies...
pip install -r "%PROJECT_ROOT%\python\requirements.txt" --quiet
echo    Dependencies installed
echo.

echo Step 5: Running prerequisites check...
echo.
cd /d "%PROJECT_ROOT%"
"%VENV_PATH%\Scripts\python.exe" -m python.cli.check
set CHECK_EXIT_CODE=%errorlevel%
echo.

if %CHECK_EXIT_CODE%==0 (
    echo ============================================================================
    echo Setup Complete!
    echo ============================================================================
    echo.
    echo Your environment is ready. To activate it in future sessions, run:
    echo.
    echo     %VENV_NAME%\Scripts\activate.bat
    echo.
    echo Or use this script again: tools\setup-env.bat
    echo.
) else (
    echo ============================================================================
    echo Setup completed with warnings
    echo ============================================================================
    echo.
    echo Please review the issues above and configure:
    echo   - Snowflake connection ^(config/.env^)
    echo   - JWT private key
    echo.
    echo Your virtual environment is active. To reactivate later:
    echo.
    echo     %VENV_NAME%\Scripts\activate.bat
    echo.
)

endlocal


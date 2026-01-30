@echo off
setlocal enabledelayedexpansion

set "INSTALL_DIR=%USERPROFILE%\.uv-manager"
set "BRANCH=dev"

echo =========================================
echo    UV ENVIRONMENT MANAGER SETUP (CMD)
echo =========================================

:: 1. Install UV
where uv >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Installing UV...
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
)

:: 2. Setup Directory
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: 3. Acquire Script (Local First)
if exist "uv-manager.bat" (
    echo Using local uv-manager.bat
    copy /Y "uv-manager.bat" "%INSTALL_DIR%\uv-manager.bat" >nul
) else (
    echo Downloading uv-manager.bat from GitHub...
    powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/superchargez/power_shelling/%BRANCH%/uv-manager.bat' -OutFile '%INSTALL_DIR%\uv-manager.bat'"
)

:: 4. Configure CMD AutoRun
echo Configuring CMD AutoRun...
set "reg_key=HKEY_CURRENT_USER\Software\Microsoft\Command Processor"
set "auto_run_cmd=if exist \"%INSTALL_DIR%\uv-manager.bat\" call \"%INSTALL_DIR%\uv-manager.bat\""

for /f "tokens=2*" %%a in ('reg query "%reg_key%" /v AutoRun 2^>nul') do set "existing_autorun=%%b"

if defined existing_autorun (
    echo %existing_autorun% | findstr /C:"uv-manager.bat" >nul
    if %ERRORLEVEL% NEQ 0 (
        reg add "%reg_key%" /v AutoRun /t REG_SZ /d "%existing_autorun% & %auto_run_cmd%" /f >nul
    )
) else (
    reg add "%reg_key%" /v AutoRun /t REG_SZ /d "%auto_run_cmd%" /f >nul
)

:: 5. Load in current session
if exist "%INSTALL_DIR%\uv-manager.bat" call "%INSTALL_DIR%\uv-manager.bat"

echo.
echo =========================================
echo INSTALLATION COMPLETE!
echo Try typing: uvl
echo =========================================
pause
@echo off
setlocal

title H1Z1 ROTK Russia - Diagnostics (v1.3.0)
color 0B

:: Locate the diagnostics engine: release (_runtime), Auto Mode install, or repository layout.
set "SCRIPT_DIR=%~dp0"
set "ENGINE="
if exist "%SCRIPT_DIR%_runtime\diagnose.ps1" set "ENGINE=%SCRIPT_DIR%_runtime\diagnose.ps1"
if not defined ENGINE if exist "%SCRIPT_DIR%diagnose.ps1" set "ENGINE=%SCRIPT_DIR%diagnose.ps1"
if not defined ENGINE if exist "%SCRIPT_DIR%scripts\diagnose.ps1" set "ENGINE=%SCRIPT_DIR%scripts\diagnose.ps1"
if not defined ENGINE if exist "%ProgramData%\H1Z1-ROTK-Russia\diagnose.ps1" set "ENGINE=%ProgramData%\H1Z1-ROTK-Russia\diagnose.ps1"

if defined ENGINE goto check_admin
echo.
echo  [ERROR] diagnose.ps1 was not found next to DIAGNOSE.cmd.
echo  Please extract the complete release archive (including the _runtime folder).
echo.
pause
exit /b 1

:check_admin
fltmc >nul 2>&1
if %errorlevel% equ 0 goto run_engine
if "%~1"=="--elevated" goto run_engine

:: Not elevated: ask Windows for administrator rights once (UAC prompt), then exit this copy.
echo.
echo  Administrator rights are needed to read the driver state.
echo  Windows will now ask for permission (UAC)...
powershell -NoProfile -Command "try { Start-Process -FilePath $env:ComSpec -ArgumentList '/c \"\"%~f0\" --elevated\"' -Verb RunAs -ErrorAction Stop; exit 0 } catch { exit 1 }"
if %errorlevel% equ 0 exit /b 0
echo.
echo  [WARN] Elevation was cancelled. Running limited diagnostics instead.
echo         For a complete report: right-click DIAGNOSE.cmd - "Run as administrator".
echo.

:run_engine
echo.
echo  Collecting diagnostics. This is READ-ONLY and takes about 20-40 seconds...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Mode Full -ReportDir "%SCRIPT_DIR%."
echo.
pause
exit /b 0

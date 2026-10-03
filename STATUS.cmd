@echo off
setlocal

title H1Z1 ROTK Russia - Status (v1.3.0)
color 0B

:: Locate the diagnostics engine: release (_runtime), Auto Mode install, or repository layout.
set "SCRIPT_DIR=%~dp0"
set "ENGINE="
if exist "%SCRIPT_DIR%_runtime\diagnose.ps1" set "ENGINE=%SCRIPT_DIR%_runtime\diagnose.ps1"
if not defined ENGINE if exist "%SCRIPT_DIR%diagnose.ps1" set "ENGINE=%SCRIPT_DIR%diagnose.ps1"
if not defined ENGINE if exist "%SCRIPT_DIR%scripts\diagnose.ps1" set "ENGINE=%SCRIPT_DIR%scripts\diagnose.ps1"
if not defined ENGINE if exist "%ProgramData%\H1Z1-ROTK-Russia\diagnose.ps1" set "ENGINE=%ProgramData%\H1Z1-ROTK-Russia\diagnose.ps1"

if defined ENGINE goto run_engine
echo.
echo  [ERROR] diagnose.ps1 was not found next to STATUS.cmd.
echo  Please extract the complete release archive (including the _runtime folder).
echo.
pause
exit /b 1

:run_engine
powershell -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Mode Status
echo.
pause
exit /b 0

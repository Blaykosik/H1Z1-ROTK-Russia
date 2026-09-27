@echo off
setlocal

:: 1. Check for Administrator privileges
net session >nul 2>&1
if %errorlevel% equ 0 goto is_admin

echo.
echo ======================================================================
echo  [ERROR] Administrator privileges are required!
echo ======================================================================
echo.
echo  Stopping the WinDivert driver service requires Administrator rights.
echo  Please right-click STOP.cmd and select "Run as administrator".
echo.
pause
exit /b 1

:is_admin
:: 2. Resolve repository directories via %~dp0
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "ROOT_DIR=%CD%"
popd
set "BIN_DIR=%ROOT_DIR%\bin"
set "PID_FILE=%BIN_DIR%\.winws.pid"

title H1Z1 ROTK Russia - Stop Bypass
color 0C

echo.
echo ======================================================================
echo           H1Z1 ROTK Russia - Stopping Bypass
echo ======================================================================
echo.

set "STOPPED=0"

if not exist "%PID_FILE%" goto check_stopped
for /f "usebackq delims=" %%P in ("%PID_FILE%") do set "TARGET_PID=%%P"
if not defined TARGET_PID goto clear_pid

powershell -NoProfile -Command "$p = Get-Process -Id %TARGET_PID% -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like '*winws*' }; if ($p) { Stop-Process -Id %TARGET_PID% -Force; exit 0 } else { exit 1 }"
if %errorlevel% neq 0 goto clear_pid

echo  [*] Terminated project winws process [PID: %TARGET_PID%]
set "STOPPED=1"

:clear_pid
if exist "%PID_FILE%" del /f /q "%PID_FILE%" >nul 2>&1

:check_stopped
if "%STOPPED%"=="0" echo  [*] No tracked active winws process found for this project.

echo  [*] Cleaning up WinDivert driver service...
sc.exe stop windivert >nul 2>&1
sc.exe delete windivert >nul 2>&1

echo.
echo  [OK] Direct UDP bypass is STOPPED. Driver unhooked.
echo.
ping 127.0.0.1 -n 2 >nul
exit /b 0

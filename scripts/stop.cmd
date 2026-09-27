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
:: 2. Resolve paths for either Release ZIP or Repository layout
set "SCRIPT_DIR=%~dp0"
if exist "%SCRIPT_DIR%_runtime\winws.exe" goto layout_root_release
if exist "%SCRIPT_DIR%winws.exe" goto layout_runtime_folder
if exist "%SCRIPT_DIR%scripts\start.cmd" goto layout_root_repo
if exist "%SCRIPT_DIR%..\bin\winws.exe" goto layout_sub_repo

:layout_runtime_folder
set "BIN_DIR=%SCRIPT_DIR%"
goto layout_resolved

:layout_root_release
set "BIN_DIR=%SCRIPT_DIR%_runtime"
goto layout_resolved

:layout_root_repo
set "BIN_DIR=%SCRIPT_DIR%bin"
goto layout_resolved

:layout_sub_repo
pushd "%SCRIPT_DIR%.."
set "ROOT_DIR=%CD%"
popd
set "BIN_DIR=%ROOT_DIR%\bin"
goto layout_resolved

:layout_resolved
set "PID_FILE=%BIN_DIR%\.winws.pid"

title H1Z1 ROTK Russia - Stop Bypass
color 0C

echo.
echo ======================================================================
echo           H1Z1 ROTK Russia - Stopping Bypass
echo ======================================================================
echo.

set "STOPPED=0"

if not exist "%PID_FILE%" goto check_stray
for /f "usebackq delims=" %%P in ("%PID_FILE%") do set "TARGET_PID=%%P"
if not defined TARGET_PID goto clear_pid

powershell -NoProfile -Command "$p = Get-Process -Id %TARGET_PID% -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like '*winws*' }; if ($null -ne $p) { Stop-Process -Id %TARGET_PID% -Force; exit 0 } else { exit 1 }"
if %errorlevel% neq 0 goto clear_pid

echo  [*] Terminated project winws process [PID: %TARGET_PID%]
set "STOPPED=1"

:clear_pid
if exist "%PID_FILE%" del /f /q "%PID_FILE%" >nul 2>&1

:check_stray
:: Also terminate any other winws process matching our project
powershell -NoProfile -Command "$procs = Get-Process -Name 'winws' -ErrorAction SilentlyContinue; if ($null -ne $procs) { $procs | Stop-Process -Force; exit 0 } else { exit 1 }" >nul 2>&1
if %errorlevel% equ 0 set "STOPPED=1"

if "%STOPPED%"=="0" echo  [*] No active winws process was running.

echo  [*] Cleaning up WinDivert driver service...
sc.exe stop windivert >nul 2>&1
sc.exe delete windivert >nul 2>&1

echo.
echo  [OK] Direct UDP bypass is STOPPED. Driver unhooked.
echo.
ping 127.0.0.1 -n 2 >nul
exit /b 0

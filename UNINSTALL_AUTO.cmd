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
echo  Removing the scheduled task and unloading the WinDivert driver
echo  requires Administrator privileges.
echo.
echo  How to run:
echo    1. Right-click UNINSTALL_AUTO.cmd
echo    2. Select "Run as administrator"
echo.
echo ======================================================================
pause
exit /b 1

:is_admin
:: 2. Resolve paths for either Release ZIP or Repository layout
set "SCRIPT_DIR=%~dp0"
if exist "%SCRIPT_DIR%_runtime\winws.exe" goto layout_root_release
if exist "%SCRIPT_DIR%winws.exe" goto layout_runtime_folder
if exist "%SCRIPT_DIR%scripts\watcher.ps1" goto layout_root_repo
if exist "%SCRIPT_DIR%..\scripts\watcher.ps1" goto layout_sub_repo

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
set "TASK_NAME=H1Z1-ROTK-Russia Auto Mode"
set "WATCHER_PID_FILE=%BIN_DIR%\.watcher.pid"
set "WINWS_PID_FILE=%BIN_DIR%\.winws.pid"

title H1Z1 ROTK Russia - Uninstall Auto Mode (v1.2.0)
color 0C

echo.
echo ======================================================================
echo       H1Z1 ROTK Russia - Uninstall Auto Mode (v1.2.0)
echo ======================================================================
echo.

:: 3. Stop and delete scheduled task
echo  [*] Removing Windows scheduled task [%TASK_NAME%]...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    schtasks /end /tn "%TASK_NAME%" >nul 2>&1
    schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
    echo  [OK] Scheduled task removed.
) else (
    echo  [*] Scheduled task was not registered.
)

:: 4. Terminate background watcher processes
echo  [*] Terminating background watcher processes...
if exist "%WATCHER_PID_FILE%" (
    for /f "usebackq delims=" %%P in ("%WATCHER_PID_FILE%") do (
        powershell -NoProfile -Command "Stop-Process -Id %%P -Force -ErrorAction SilentlyContinue" >nul 2>&1
    )
    del /f /q "%WATCHER_PID_FILE%" >nul 2>&1
)

:: Also terminate any stray watcher instances
powershell -NoProfile -Command "$w = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*watcher.ps1*' }; if ($w) { $w | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } }" >nul 2>&1

:: 5. Terminate active bypass and unload WinDivert driver
echo  [*] Terminating active bypass and unloading driver...
if exist "%WINWS_PID_FILE%" (
    for /f "usebackq delims=" %%P in ("%WINWS_PID_FILE%") do (
        powershell -NoProfile -Command "$p = Get-Process -Id %%P -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like '*winws*' }; if ($p) { Stop-Process -Id %%P -Force }" >nul 2>&1
    )
    del /f /q "%WINWS_PID_FILE%" >nul 2>&1
)

sc.exe stop windivert >nul 2>&1
sc.exe delete windivert >nul 2>&1

echo.
echo ======================================================================
echo  [SUCCESS] Auto Mode has been completely UNINSTALLED!
echo ======================================================================
echo.
echo  - Scheduled task deleted from Windows Task Scheduler.
echo  - Headless watcher stopped.
echo  - WinDivert kernel driver unloaded.
echo  - System restored to default state.
echo.
pause
exit /b 0

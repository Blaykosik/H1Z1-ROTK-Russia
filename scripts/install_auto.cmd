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
echo  Installing Auto Mode as a Windows scheduled task requires Administrator
echo  rights so that WinDivert driver can be loaded when H1Z1 starts.
echo.
echo  How to run:
echo    1. Right-click INSTALL_AUTO.cmd (or scripts\install_auto.cmd)
echo    2. Select "Run as administrator"
echo.
echo ======================================================================
pause
exit /b 1

:is_admin
:: 2. Resolve paths for either Release ZIP or Repository layout
set "SCRIPT_DIR=%~dp0"
if exist "%SCRIPT_DIR%_runtime\watcher.ps1" goto layout_root_release
if exist "%SCRIPT_DIR%watcher.ps1" goto layout_scripts_folder
if exist "%SCRIPT_DIR%scripts\watcher.ps1" goto layout_root_repo
if exist "%SCRIPT_DIR%..\scripts\watcher.ps1" goto layout_sub_repo

:layout_scripts_folder
set "WATCHER_SCRIPT=%SCRIPT_DIR%watcher.ps1"
if exist "%SCRIPT_DIR%..\bin\winws.exe" (
    pushd "%SCRIPT_DIR%.."
    set "ROOT_DIR=%CD%"
    popd
    set "BIN_DIR=%ROOT_DIR%\bin"
) else (
    set "BIN_DIR=%SCRIPT_DIR%"
)
goto layout_resolved

:layout_root_release
set "WATCHER_SCRIPT=%SCRIPT_DIR%_runtime\watcher.ps1"
set "BIN_DIR=%SCRIPT_DIR%_runtime"
goto layout_resolved

:layout_root_repo
set "WATCHER_SCRIPT=%SCRIPT_DIR%scripts\watcher.ps1"
set "BIN_DIR=%SCRIPT_DIR%bin"
goto layout_resolved

:layout_sub_repo
pushd "%SCRIPT_DIR%.."
set "ROOT_DIR=%CD%"
popd
set "WATCHER_SCRIPT=%ROOT_DIR%\scripts\watcher.ps1"
set "BIN_DIR=%ROOT_DIR%\bin"
goto layout_resolved

:layout_resolved
set "TASK_NAME=H1Z1-ROTK-Russia Auto Mode"
set "WATCHER_PID_FILE=%BIN_DIR%\.watcher.pid"
set "WINWS_PID_FILE=%BIN_DIR%\.winws.pid"

title H1Z1 ROTK Russia - Install Auto Mode (v1.2.0)
color 0B

echo.
echo ======================================================================
echo        H1Z1 ROTK Russia - Install Auto Mode (v1.2.0)
echo ======================================================================
echo.
echo  Auto Mode features:
echo    - Event-driven monitoring via Windows WMI (no busy polling, ~0%% CPU)
echo    - Bypass starts AUTOMATICALLY when H1Z1.exe launches
echo    - Bypass stops AUTOMATICALLY 7 seconds after H1Z1.exe exits
echo    - Starts silently at Windows user logon (no GUI, no popup windows)
echo.
echo  Watcher Script : %WATCHER_SCRIPT%
echo  Runtime Folder : %BIN_DIR%
echo.

if not exist "%WATCHER_SCRIPT%" goto error_missing_script

:: 3. Stop and delete any pre-existing task instance
echo  [*] Checking for previous task installation...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    echo  [*] Stopping previous task instance...
    schtasks /end /tn "%TASK_NAME%" >nul 2>&1
    schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
)

:: 4. Stop any running watcher process
if exist "%WATCHER_PID_FILE%" (
    for /f "usebackq delims=" %%P in ("%WATCHER_PID_FILE%") do (
        powershell -NoProfile -Command "Stop-Process -Id %%P -Force -ErrorAction SilentlyContinue" >nul 2>&1
    )
    del /f /q "%WATCHER_PID_FILE%" >nul 2>&1
)

:: 5. Register scheduled task (AtLogon with HighestAvailable privileges)
echo  [*] Registering scheduled task [%TASK_NAME%]...
schtasks /create /tn "%TASK_NAME%" /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%WATCHER_SCRIPT%\"" /sc onlogon /rl highest /f >nul 2>&1

if %errorlevel% neq 0 goto error_task_create

echo  [OK] Task registered successfully.
echo.

:: 6. Launch watcher immediately
echo  [*] Starting Auto Mode watcher service...
schtasks /run /tn "%TASK_NAME%" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [*] Launching background watcher directly...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%WATCHER_SCRIPT%\"' -WindowStyle Hidden" >nul 2>&1
)

ping 127.0.0.1 -n 3 >nul

:: 7. Verify watcher is running
set "WATCHER_RUNNING=0"
if not exist "%WATCHER_PID_FILE%" goto verify_via_process
for /f "usebackq delims=" %%P in ("%WATCHER_PID_FILE%") do set "W_PID=%%P"
if defined W_PID (
    powershell -NoProfile -Command "$p = Get-Process -Id %W_PID% -ErrorAction SilentlyContinue; if ($p) { exit 0 } else { exit 1 }"
    if %errorlevel% equ 0 set "WATCHER_RUNNING=1"
)

:verify_via_process
if "%WATCHER_RUNNING%"=="0" (
    powershell -NoProfile -Command "$p = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*watcher.ps1*' }; if ($p) { exit 0 } else { exit 1 }"
    if %errorlevel% equ 0 set "WATCHER_RUNNING=1"
)

echo.
echo ======================================================================
if "%WATCHER_RUNNING%"=="1" (
    echo  [SUCCESS] Auto Mode is INSTALLED and ACTIVE!
) else (
    echo  [NOTE] Auto Mode task registered and will trigger on next login.
)
echo ======================================================================
echo.
echo  You do not need to keep any console windows open.
echo  You do not need to manually run START.cmd anymore.
echo.
echo  To check current status at any time, run STATUS.cmd.
echo  To uninstall Auto Mode, run UNINSTALL_AUTO.cmd as administrator.
echo.
pause
exit /b 0

:error_missing_script
echo  [ERROR] Cannot find watcher script:
echo  %WATCHER_SCRIPT%
echo.
pause
exit /b 1

:error_task_create
echo  [ERROR] Failed to register Windows scheduled task.
echo  Ensure you ran this script as Administrator.
echo.
pause
exit /b 1

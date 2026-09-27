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
echo  Installing Auto Mode into %ProgramData% and registering a Windows
echo  scheduled task requires Administrator rights.
echo.
echo  How to run:
echo    1. Right-click INSTALL_AUTO.cmd
echo    2. Select "Run as administrator"
echo.
echo ======================================================================
pause
exit /b 1

:is_admin
:: 2. Target installation directory
set "TARGET_DIR=%ProgramData%\H1Z1-ROTK-Russia"
set "TASK_NAME=H1Z1-ROTK-Russia Auto Mode"

title H1Z1 ROTK Russia - Install Auto Mode (v1.2.1)
color 0B

echo.
echo ======================================================================
echo        H1Z1 ROTK Russia - Install Auto Mode (v1.2.1)
echo ======================================================================
echo.
echo  Auto Mode features:
echo    - Event-driven monitoring via Windows WMI (no busy polling, ~0%% CPU)
echo    - Low-frequency safety reconciliation in case of missed OS events
echo    - Bypass starts AUTOMATICALLY when H1Z1.exe launches
echo    - Bypass stops AUTOMATICALLY 7 seconds after H1Z1.exe exits
echo    - Unloads WinDivert driver whenever the game is not running
echo    - Isolated: strictly manages this project; never touches other tools
echo.
echo  Target Location: %TARGET_DIR%
echo.

:: 3. Resolve source files
set "SCRIPT_DIR=%~dp0"
if exist "%SCRIPT_DIR%_runtime\winws.exe" goto src_release_root
if exist "%SCRIPT_DIR%bin\winws.exe" goto src_repo_root
if exist "%SCRIPT_DIR%..\bin\winws.exe" goto src_repo_scripts
if exist "%SCRIPT_DIR%winws.exe" goto src_runtime_direct

:src_release_root
set "SRC_RUNTIME=%SCRIPT_DIR%_runtime"
set "SRC_ROOT=%SCRIPT_DIR%"
goto copy_files

:src_repo_root
set "SRC_RUNTIME=%SCRIPT_DIR%bin"
set "SRC_ROOT=%SCRIPT_DIR%"
goto copy_repo_files

:src_repo_scripts
pushd "%SCRIPT_DIR%.."
set "SRC_ROOT=%CD%"
popd
set "SRC_RUNTIME=%SRC_ROOT%\bin"
goto copy_repo_files

:src_runtime_direct
set "SRC_RUNTIME=%SCRIPT_DIR%"
set "SRC_ROOT=%SCRIPT_DIR%"
goto copy_files

:copy_files
echo  [*] Creating installation directory: %TARGET_DIR%...
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%" >nul 2>&1
if not exist "%TARGET_DIR%\licenses" mkdir "%TARGET_DIR%\licenses" >nul 2>&1

echo  [*] Copying runtime files...
copy /y "%SRC_RUNTIME%\winws.exe" "%TARGET_DIR%\winws.exe" >nul
copy /y "%SRC_RUNTIME%\WinDivert.dll" "%TARGET_DIR%\WinDivert.dll" >nul
copy /y "%SRC_RUNTIME%\WinDivert64.sys" "%TARGET_DIR%\WinDivert64.sys" >nul
copy /y "%SRC_RUNTIME%\cygwin1.dll" "%TARGET_DIR%\cygwin1.dll" >nul
copy /y "%SRC_RUNTIME%\stun.bin" "%TARGET_DIR%\stun.bin" >nul
copy /y "%SRC_RUNTIME%\filter.txt" "%TARGET_DIR%\filter.txt" >nul
copy /y "%SRC_RUNTIME%\rotk_winws.conf" "%TARGET_DIR%\rotk_winws.conf" >nul
copy /y "%SRC_RUNTIME%\watcher.ps1" "%TARGET_DIR%\watcher.ps1" >nul

if exist "%SRC_ROOT%\UNINSTALL_AUTO.cmd" copy /y "%SRC_ROOT%\UNINSTALL_AUTO.cmd" "%TARGET_DIR%\UNINSTALL_AUTO.cmd" >nul
if exist "%SRC_RUNTIME%\UNINSTALL_AUTO.cmd" copy /y "%SRC_RUNTIME%\UNINSTALL_AUTO.cmd" "%TARGET_DIR%\UNINSTALL_AUTO.cmd" >nul
if exist "%SRC_ROOT%\STATUS.cmd" copy /y "%SRC_ROOT%\STATUS.cmd" "%TARGET_DIR%\STATUS.cmd" >nul
if exist "%SRC_RUNTIME%\STATUS.cmd" copy /y "%SRC_RUNTIME%\STATUS.cmd" "%TARGET_DIR%\STATUS.cmd" >nul
if exist "%SRC_RUNTIME%\licenses" xcopy /y /s /q "%SRC_RUNTIME%\licenses\*" "%TARGET_DIR%\licenses\" >nul

goto configure_task

:copy_repo_files
echo  [*] Creating installation directory: %TARGET_DIR%...
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%" >nul 2>&1
if not exist "%TARGET_DIR%\licenses" mkdir "%TARGET_DIR%\licenses" >nul 2>&1

echo  [*] Copying runtime files from repository...
copy /y "%SRC_ROOT%\bin\winws.exe" "%TARGET_DIR%\winws.exe" >nul
copy /y "%SRC_ROOT%\bin\WinDivert.dll" "%TARGET_DIR%\WinDivert.dll" >nul
copy /y "%SRC_ROOT%\bin\WinDivert64.sys" "%TARGET_DIR%\WinDivert64.sys" >nul
copy /y "%SRC_ROOT%\bin\cygwin1.dll" "%TARGET_DIR%\cygwin1.dll" >nul
copy /y "%SRC_ROOT%\bin\stun.bin" "%TARGET_DIR%\stun.bin" >nul
copy /y "%SRC_ROOT%\config\filter.txt" "%TARGET_DIR%\filter.txt" >nul
copy /y "%SRC_ROOT%\scripts\watcher.ps1" "%TARGET_DIR%\watcher.ps1" >nul
if exist "%SRC_ROOT%\UNINSTALL_AUTO.cmd" copy /y "%SRC_ROOT%\UNINSTALL_AUTO.cmd" "%TARGET_DIR%\UNINSTALL_AUTO.cmd" >nul
if exist "%SRC_ROOT%\scripts\uninstall_auto.cmd" copy /y "%SRC_ROOT%\scripts\uninstall_auto.cmd" "%TARGET_DIR%\UNINSTALL_AUTO.cmd" >nul
if exist "%SRC_ROOT%\STATUS.cmd" copy /y "%SRC_ROOT%\STATUS.cmd" "%TARGET_DIR%\STATUS.cmd" >nul
if exist "%SRC_ROOT%\scripts\status.cmd" copy /y "%SRC_ROOT%\scripts\status.cmd" "%TARGET_DIR%\STATUS.cmd" >nul
if exist "%SRC_ROOT%\LICENSES" xcopy /y /s /q "%SRC_ROOT%\LICENSES\*" "%TARGET_DIR%\licenses\" >nul

:: Create rotk_winws.conf in target pointing to local filter.txt
(
    echo --wf-raw=@filter.txt
    echo --dpi-desync=fake
    echo --dpi-desync-any-protocol=1
    echo --dpi-desync-fake-unknown-udp=stun.bin
    echo --dpi-desync-cutoff=d2
) > "%TARGET_DIR%\rotk_winws.conf"

goto configure_task

:configure_task
:: 4. Stop pre-existing task instance and any old watcher running from ProgramData
echo  [*] Cleaning up any previous installation...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    schtasks /end /tn "%TASK_NAME%" >nul 2>&1
    schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
)

:: Terminate old watcher if tracked
if exist "%TARGET_DIR%\.watcher.pid" (
    powershell -NoProfile -Command "$wPid = (Get-Content '%TARGET_DIR%\.watcher.pid' -ErrorAction SilentlyContinue | Select -First 1).Trim(); if ($wPid -match '^\d+$') { Stop-Process -Id ([int]$wPid) -Force -ErrorAction SilentlyContinue }" >nul 2>&1
    del /f /q "%TARGET_DIR%\.watcher.pid" >nul 2>&1
)

:: Stop old bypass ONLY if it matches our target winws
if exist "%TARGET_DIR%\.winws.pid" (
    powershell -NoProfile -Command "$exp = [System.IO.Path]::GetFullPath('%TARGET_DIR%\winws.exe'); $tPid = (Get-Content '%TARGET_DIR%\.winws.pid' -ErrorAction SilentlyContinue | Select -First 1).Trim(); if ($tPid -match '^\d+$') { $p = Get-Process -Id ([int]$tPid) -ErrorAction SilentlyContinue; if ($null -ne $p -and [System.IO.Path]::GetFullPath($p.Path) -eq $exp) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } }" >nul 2>&1
    del /f /q "%TARGET_DIR%\.winws.pid" >nul 2>&1
)

:: 5. Register scheduled task pointing to %ProgramData%\H1Z1-ROTK-Russia\watcher.ps1
echo  [*] Registering scheduled task [%TASK_NAME%]...
schtasks /create /tn "%TASK_NAME%" /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%TARGET_DIR%\watcher.ps1\"" /sc onlogon /rl highest /f >nul 2>&1

if %errorlevel% neq 0 goto error_task_create

echo  [OK] Task registered successfully.

:: 6. Launch watcher immediately
echo  [*] Starting Auto Mode watcher service...
schtasks /run /tn "%TASK_NAME%" >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%TARGET_DIR%\watcher.ps1\"' -WindowStyle Hidden" >nul 2>&1
)

ping 127.0.0.1 -n 3 >nul

:: 7. Verify watcher is running
set "WATCHER_RUNNING=0"
if exist "%TARGET_DIR%\.watcher.pid" (
    for /f "usebackq delims=" %%P in ("%TARGET_DIR%\.watcher.pid") do (
        powershell -NoProfile -Command "$p = Get-Process -Id ([int]'%%P') -ErrorAction SilentlyContinue; if ($null -ne $p) { exit 0 } else { exit 1 }"
        if %errorlevel% equ 0 set "WATCHER_RUNNING=1"
    )
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
echo  Installed Location: %TARGET_DIR%
echo.
echo  [*] IMPORTANT UX NOTE:
echo      The bypass runtime is now installed in ProgramData.
echo      You can safely MOVE or DELETE the downloaded release folder!
echo.
echo  To check current status at any time, run STATUS.cmd.
echo  To uninstall Auto Mode, run UNINSTALL_AUTO.cmd (from this folder
echo  or directly from %TARGET_DIR%\UNINSTALL_AUTO.cmd).
echo.
pause
exit /b 0

:error_task_create
echo  [ERROR] Failed to register Windows scheduled task.
echo  Ensure you ran this script as Administrator.
echo.
pause
exit /b 1

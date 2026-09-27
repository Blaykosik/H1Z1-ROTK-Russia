@echo off
setlocal

set "TARGET_DIR=%ProgramData%\H1Z1-ROTK-Russia"
set "TASK_NAME=H1Z1-ROTK-Russia Auto Mode"
set "SCRIPT_DIR=%~dp0"

if exist "%SCRIPT_DIR%_runtime\winws.exe" (
    set "LOCAL_BIN=%SCRIPT_DIR%_runtime"
) else if exist "%SCRIPT_DIR%winws.exe" (
    set "LOCAL_BIN=%SCRIPT_DIR%"
) else if exist "%SCRIPT_DIR%bin\winws.exe" (
    set "LOCAL_BIN=%SCRIPT_DIR%bin"
) else if exist "%SCRIPT_DIR%..\bin\winws.exe" (
    pushd "%SCRIPT_DIR%.."
    set "LOCAL_BIN=%CD%\bin"
    popd
) else (
    set "LOCAL_BIN=%SCRIPT_DIR%"
)

title H1Z1 ROTK Russia - Status Diagnostic (v1.2.1)
color 0B

echo.
echo ======================================================================
echo           H1Z1 ROTK Russia - Status Diagnostic (v1.2.1)
echo ======================================================================
echo.
echo  Project Version   : v1.2.1
echo  Engine            : winws [zapret v72.13 x86_64] + WinDivert
echo.

:: 1. Check Scheduled Task
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %errorlevel% equ 0 goto task_installed
echo  Auto Mode Task    : NOT INSTALLED
goto check_watcher

:task_installed
echo  Auto Mode Task    : INSTALLED [ENABLED]
echo  Installed Path    : %TARGET_DIR%

:check_watcher
:: 2. Check Watcher Process via tracked PID files (ProgramData or local)
set "WATCHER_PID="
if exist "%TARGET_DIR%\.watcher.pid" (
    for /f "usebackq delims=" %%P in ("%TARGET_DIR%\.watcher.pid") do set "W_TRY=%%P"
)
if not defined W_TRY if exist "%LOCAL_BIN%\.watcher.pid" (
    for /f "usebackq delims=" %%P in ("%LOCAL_BIN%\.watcher.pid") do set "W_TRY=%%P"
)

if defined W_TRY (
    powershell -NoProfile -Command "try { $p = Get-Process -Id ([int]'%W_TRY%') -ErrorAction Stop; if ($p.ProcessName -like '*powershell*') { exit 0 } } catch {}; exit 1"
    if %errorlevel% equ 0 set "WATCHER_PID=%W_TRY%"
)

if defined WATCHER_PID goto show_watcher_running
echo  Auto Watcher      : INACTIVE
goto check_game

:show_watcher_running
echo  Auto Watcher      : RUNNING [PID: %WATCHER_PID%]

:check_game
:: 3. Check Game Process (H1Z1.exe)
powershell -NoProfile -Command "$p = Get-Process -Name 'H1Z1' -ErrorAction SilentlyContinue; if ($p) { exit 0 } else { exit 1 }"
if %errorlevel% equ 0 goto show_game_running
echo  Game Process      : NOT RUNNING [H1Z1.exe]
goto check_bypass

:show_game_running
echo  Game Process      : RUNNING [H1Z1.exe]

:check_bypass
:: 4. Check Project Bypass vs Other winws instances
set "PROJECT_PID="
set "OTHER_PID="

:: Use PowerShell to evaluate processes accurately
for /f "tokens=1,2" %%A in ('powershell -NoProfile -Command ^
    "$expA = [System.IO.Path]::GetFullPath('%TARGET_DIR%\winws.exe');" ^
    "$expB = [System.IO.Path]::GetFullPath('%LOCAL_BIN%\winws.exe');" ^
    "$projPid = 'NONE';" ^
    "$otherPid = 'NONE';" ^
    "if (Test-Path '%TARGET_DIR%\.winws.pid') { $raw = (Get-Content '%TARGET_DIR%\.winws.pid' | Select -First 1).Trim(); if ($raw -match '^\d+$') { $p = Get-Process -Id ([int]$raw) -ErrorAction SilentlyContinue; if ($null -ne $p -and ([System.IO.Path]::GetFullPath($p.Path) -eq $expA -or [System.IO.Path]::GetFullPath($p.Path) -eq $expB)) { $projPid = $p.Id } } };" ^
    "if ($projPid -eq 'NONE' -and (Test-Path '%LOCAL_BIN%\.winws.pid')) { $raw = (Get-Content '%LOCAL_BIN%\.winws.pid' | Select -First 1).Trim(); if ($raw -match '^\d+$') { $p = Get-Process -Id ([int]$raw) -ErrorAction SilentlyContinue; if ($null -ne $p -and ([System.IO.Path]::GetFullPath($p.Path) -eq $expA -or [System.IO.Path]::GetFullPath($p.Path) -eq $expB)) { $projPid = $p.Id } } };" ^
    "$all = Get-Process -Name 'winws' -ErrorAction SilentlyContinue;" ^
    "if ($null -ne $all) { foreach ($w in $all) { if ([string]$w.Id -ne [string]$projPid) { $otherPid = $w.Id; break } } };" ^
    "Write-Output ([string]$projPid + ' ' + [string]$otherPid)"') do (
    set "PROJECT_PID=%%A"
    set "OTHER_PID=%%B"
)

echo.
if "%PROJECT_PID%"=="NONE" goto show_bypass_inactive
echo  H1Z1 ROTK Bypass  : ACTIVE [PROTECTING] [PID: %PROJECT_PID%]
echo  Scope Filter      : 162.19.94.95, 162.19.126.0/24 [UDP 20000-23000]
echo  Desync Strategy   : Single-packet STUN prefix [cutoff=d2]
goto show_other

:show_bypass_inactive
echo  H1Z1 ROTK Bypass  : INACTIVE

:show_other
if "%OTHER_PID%"=="NONE" goto show_no_other
echo  Other winws       : DETECTED [PID: %OTHER_PID%, not managed]
goto show_driver

:show_no_other
echo  Other winws       : NOT DETECTED

:show_driver
echo.
echo  Driver Service    :
sc.exe query windivert 2>&1 | findstr /i "STATE"
if %errorlevel% neq 0 echo    STATE : NOT INSTALLED / STOPPED

echo.
echo ======================================================================
echo.
pause
exit /b 0

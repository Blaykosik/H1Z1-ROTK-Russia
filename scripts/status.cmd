@echo off
setlocal

:: Resolve paths for either Release ZIP or Repository layout
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

title H1Z1 ROTK Russia - Status Diagnostic (v1.2.0)
color 0B

echo.
echo ======================================================================
echo           H1Z1 ROTK Russia - Status Diagnostic (v1.2.0)
echo ======================================================================
echo.
echo  Project Version   : v1.2.0
echo  Engine            : winws [zapret v72.13 x86_64] + WinDivert
echo.

:: 1. Check Scheduled Task
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %errorlevel% equ 0 goto task_installed
echo  Auto Mode Task    : NOT INSTALLED
goto check_watcher

:task_installed
echo  Auto Mode Task    : INSTALLED [ENABLED]

:check_watcher
:: 2. Check Watcher Process via tracked PID file
set "WATCHER_PID="
if not exist "%WATCHER_PID_FILE%" goto show_watcher_inactive
for /f "usebackq delims=" %%P in ("%WATCHER_PID_FILE%") do set "WATCHER_PID=%%P"
if not defined WATCHER_PID goto show_watcher_inactive

powershell -NoProfile -Command "try { $p = Get-Process -Id %WATCHER_PID% -ErrorAction Stop; if ($p.ProcessName -like '*powershell*') { exit 0 } } catch {}; exit 1"
if %errorlevel% equ 0 goto show_watcher_running

:show_watcher_inactive
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
:: 4. Check Bypass Process (winws.exe)
set "WINWS_PID="
if not exist "%WINWS_PID_FILE%" goto check_any_winws
for /f "usebackq delims=" %%P in ("%WINWS_PID_FILE%") do set "WINWS_PID=%%P"
if not defined WINWS_PID goto check_any_winws

powershell -NoProfile -Command "try { $p = Get-Process -Id %WINWS_PID% -ErrorAction Stop; if ($p.ProcessName -like '*winws*') { exit 0 } } catch {}; exit 1"
if %errorlevel% equ 0 goto show_bypass_active

:check_any_winws
powershell -NoProfile -Command "$p = Get-Process -Name 'winws' -ErrorAction SilentlyContinue; if ($p) { exit 0 } else { exit 1 }"
if %errorlevel% equ 0 goto show_bypass_untracked

echo.
echo  Bypass Status     : INACTIVE [NOT RUNNING]
goto show_driver

:show_bypass_active
echo.
echo  Bypass Status     : ACTIVE [PROTECTING]
echo  Process PID       : %WINWS_PID%
echo  Scope Filter      : 162.19.94.95, 162.19.126.0/24 [UDP 20000-23000]
echo  Desync Strategy   : Single-packet STUN prefix [cutoff=d2]
goto show_driver

:show_bypass_untracked
echo.
echo  Bypass Status     : ACTIVE [UNTRACKED winws]
echo  Scope Filter      : 162.19.94.95, 162.19.126.0/24 [UDP 20000-23000]
echo  Desync Strategy   : Single-packet STUN prefix [cutoff=d2]

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

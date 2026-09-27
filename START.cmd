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
echo  WinDivert operates as a Windows network packet filter driver and
echo  requires Administrator rights to intercept and desync ROTK UDP flows.
echo.
echo  How to run:
echo    1. Right-click START.cmd
echo    2. Select "Run as administrator"
echo.
echo ======================================================================
pause
exit /b 1

:is_admin
:: 2. Resolve paths for either Release ZIP or Repository layout
set "SCRIPT_DIR=%~dp0"
if exist "%SCRIPT_DIR%_runtime\winws.exe" goto layout_root_release
if exist "%SCRIPT_DIR%bin\winws.exe" goto layout_root_repo
if exist "%SCRIPT_DIR%winws.exe" goto layout_runtime_folder
if exist "%SCRIPT_DIR%..\bin\winws.exe" goto layout_sub_repo

:layout_runtime_folder
set "ROOT_DIR=%SCRIPT_DIR%.."
set "BIN_DIR=%SCRIPT_DIR%"
set "CONFIG_DIR=%SCRIPT_DIR%"
set "CONF_FILE=%CONFIG_DIR%\rotk_winws.conf"
goto layout_resolved

:layout_root_release
set "ROOT_DIR=%SCRIPT_DIR%"
set "BIN_DIR=%SCRIPT_DIR%_runtime"
set "CONFIG_DIR=%SCRIPT_DIR%_runtime"
set "CONF_FILE=%CONFIG_DIR%\rotk_winws.conf"
goto layout_resolved

:layout_root_repo
set "ROOT_DIR=%SCRIPT_DIR%"
set "BIN_DIR=%SCRIPT_DIR%bin"
set "CONFIG_DIR=%SCRIPT_DIR%config"
set "CONF_FILE=%CONFIG_DIR%\rotk_winws.conf"
goto layout_resolved

:layout_sub_repo
pushd "%SCRIPT_DIR%.."
set "ROOT_DIR=%CD%"
popd
set "BIN_DIR=%ROOT_DIR%\bin"
set "CONFIG_DIR=%ROOT_DIR%\config"
set "CONF_FILE=%CONFIG_DIR%\rotk_winws.conf"
goto layout_resolved

:layout_resolved
set "PID_FILE=%BIN_DIR%\.winws.pid"
set "EXPECTED_EXE=%BIN_DIR%\winws.exe"

title H1Z1 ROTK Russia - Direct UDP Bypass v1.2.1 (Portable)
color 0A

:: 3. Verify presence of required runtime files
set "MISSING="
if not exist "%BIN_DIR%\winws.exe" set "MISSING=winws.exe"
if not exist "%BIN_DIR%\WinDivert.dll" set "MISSING=WinDivert.dll"
if not exist "%BIN_DIR%\WinDivert64.sys" set "MISSING=WinDivert64.sys"
if not exist "%BIN_DIR%\cygwin1.dll" set "MISSING=cygwin1.dll"
if not exist "%BIN_DIR%\stun.bin" set "MISSING=stun.bin"
if not exist "%CONFIG_DIR%\filter.txt" set "MISSING=filter.txt"
if not exist "%CONF_FILE%" set "MISSING=rotk_winws.conf"

if not defined MISSING goto check_existing_pid
echo.
echo [ERROR] Required runtime file is missing: %MISSING%
echo Expected directory: %BIN_DIR%
echo Please make sure you extracted the entire release archive.
echo.
pause
exit /b 1

:check_existing_pid
if not exist "%PID_FILE%" goto do_start
for /f "usebackq delims=" %%P in ("%PID_FILE%") do set "EXISTING_PID=%%P"
if not defined EXISTING_PID goto clear_old_pid

:: Validate PID and path
powershell -NoProfile -Command "$exp = [System.IO.Path]::GetFullPath('%EXPECTED_EXE%'); $p = Get-Process -Id ([int]'%EXISTING_PID%') -ErrorAction SilentlyContinue; if ($null -ne $p -and [System.IO.Path]::GetFullPath($p.Path) -eq $exp) { exit 0 } else { exit 1 }"
if %errorlevel% neq 0 goto clear_old_pid

echo.
echo ======================================================================
echo  [INFO] Direct UDP bypass is ALREADY ACTIVE [PID: %EXISTING_PID%]
echo ======================================================================
echo.
echo  ROTK UDP filter is currently active and protecting the connection.
echo  You can launch ROTK and play directly.
echo.
echo  To stop the bypass, run STOP.cmd.
echo ======================================================================
echo.
pause
exit /b 0

:clear_old_pid
if exist "%PID_FILE%" del /f /q "%PID_FILE%" >nul 2>&1

:do_start
echo.
echo ======================================================================
echo        H1Z1 ROTK Russia - Direct UDP Bypass v1.2.1 (Portable)
echo ======================================================================
echo.
echo  [*] Mode              : Portable (runs directly from this folder)
echo  [*] Target Scope:
echo      - Login / Gateway : 162.19.94.95
echo      - Match Servers   : 162.19.126.0/24 [162.19.126.0 - 162.19.126.255]
echo      - Protocol / Ports: UDP 20000 - 23000
echo.
echo  [*] Network Profile   : Native Direct UDP [No VPN / No Proxy / No Relay]
echo  [*] Desync Method     : Single-packet STUN prefix [cutoff=d2]
echo  [*] Observed Latency  : ~55 - 61 ms [on tested ISP path]
echo.
echo  [*] Starting WinDivert filter...

powershell -NoProfile -ExecutionPolicy Bypass -Command "$proc = Start-Process -FilePath '%EXPECTED_EXE%' -ArgumentList '@%CONF_FILE%' -WorkingDirectory '%BIN_DIR%' -WindowStyle Minimized -PassThru; $proc.Id | Out-File -FilePath '%PID_FILE%' -Encoding ascii"

ping 127.0.0.1 -n 3 >nul

if not exist "%PID_FILE%" goto start_failed
for /f "usebackq delims=" %%P in ("%PID_FILE%") do set "NEW_PID=%%P"
if not defined NEW_PID goto start_failed

powershell -NoProfile -Command "$p = Get-Process -Id ([int]'%NEW_PID%') -ErrorAction SilentlyContinue; if ($null -ne $p -and $p.Path -eq '%EXPECTED_EXE%') { exit 0 } else { exit 1 }"
if %errorlevel% neq 0 goto start_failed

echo  [OK] Bypass filter is ACTIVE [PID: %NEW_PID%]
echo.
echo ----------------------------------------------------------------------
echo  You can now launch ROTK normally and play.
echo.
echo  When finished playing, you can:
echo    - Press any key in this window to stop the bypass and exit, OR
echo    - Close this window and run STOP.cmd when done.
echo ----------------------------------------------------------------------
echo.
pause >nul

if exist "%SCRIPT_DIR%STOP.cmd" (
    call "%SCRIPT_DIR%STOP.cmd"
) else if exist "%ROOT_DIR%\STOP.cmd" (
    call "%ROOT_DIR%\STOP.cmd"
) else (
    powershell -NoProfile -Command "$p = Get-Process -Id ([int]'%NEW_PID%') -ErrorAction SilentlyContinue; if ($null -ne $p -and $p.Path -eq '%EXPECTED_EXE%') { Stop-Process -Id $p.Id -Force }" >nul 2>&1
    del /f /q "%PID_FILE%" >nul 2>&1
)
exit /b 0

:start_failed
echo  [ERROR] Failed to start winws.exe.
echo  Please verify that your antivirus or another WinDivert tool [zapret/GoodbyeDPI]
echo  is not blocking or holding the driver.
echo.
pause
exit /b 1

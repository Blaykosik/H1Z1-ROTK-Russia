@echo off
setlocal

:: 1. Check for Administrator privileges
fltmc >nul 2>&1
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

title H1Z1 ROTK Russia - Direct UDP Bypass v1.3.0 (Portable)
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
echo        H1Z1 ROTK Russia - Direct UDP Bypass v1.3.0 (Portable)
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
echo  [*] Latency           : defined by your ISP route to ROTK [not changed by this tool]
echo.
echo  [*] Starting WinDivert filter...

:: Start winws and validate it for 2.5 s. winws exits immediately with the Win32 error code
:: when WinDivertOpen fails, so the exit code identifies the exact driver problem.
set "LAST_ERR_FILE=%BIN_DIR%\.last_start_error.txt"
set "START_RESULT="
for /f "usebackq delims=" %%R in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $proc = Start-Process -FilePath '%EXPECTED_EXE%' -ArgumentList '@%CONF_FILE%' -WorkingDirectory '%BIN_DIR%' -WindowStyle Minimized -PassThru -ErrorAction Stop } catch { $e = $_.Exception; while ($e -and -not ($e -is [ComponentModel.Win32Exception])) { $e = $e.InnerException }; $c = -1; if ($e) { $c = $e.NativeErrorCode }; Write-Output ('launch ' + $c); exit }; $null = $proc.Handle; $t = [Diagnostics.Stopwatch]::StartNew(); while (-not $proc.HasExited -and $t.ElapsedMilliseconds -lt 2500) { Start-Sleep -Milliseconds 250 }; if ($proc.HasExited) { Write-Output ('driver ' + $proc.ExitCode) } else { $proc.Id | Out-File -FilePath '%PID_FILE%' -Encoding ascii; Write-Output ('ok ' + $proc.Id) }"`) do set "START_RESULT=%%R"

for /f "tokens=1,2" %%A in ("%START_RESULT%") do (
    set "START_STAGE=%%A"
    set "START_CODE=%%B"
)
if not "%START_STAGE%"=="ok" goto start_failed
set "NEW_PID=%START_CODE%"

if exist "%LAST_ERR_FILE%" del /f /q "%LAST_ERR_FILE%" >nul 2>&1
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
if not defined START_STAGE set "START_STAGE=driver"
if not defined START_CODE set "START_CODE=-1"
if exist "%PID_FILE%" del /f /q "%PID_FILE%" >nul 2>&1
powershell -NoProfile -Command "((Get-Date -Format s) + ';stage=%START_STAGE%;code=%START_CODE%;source=START') | Out-File -FilePath '%LAST_ERR_FILE%' -Encoding ascii" >nul 2>&1

set "ENGINE="
if exist "%BIN_DIR%\diagnose.ps1" set "ENGINE=%BIN_DIR%\diagnose.ps1"
if not defined ENGINE if exist "%ROOT_DIR%\scripts\diagnose.ps1" set "ENGINE=%ROOT_DIR%\scripts\diagnose.ps1"
if defined ENGINE (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Mode Startup -StartupStage %START_STAGE% -StartupCode %START_CODE%
) else (
    echo  [ERROR] winws.exe failed to start [stage: %START_STAGE%, code: %START_CODE%].
    echo  Run DIAGNOSE.cmd for details.
)
echo.
pause
exit /b 1

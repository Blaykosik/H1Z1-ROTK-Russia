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
echo  Stopping the WinDivert driver service requires Administrator rights.
echo  Please right-click STOP.cmd and select "Run as administrator".
echo.
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
set "EXPECTED_EXE=%BIN_DIR%\winws.exe"

title H1Z1 ROTK Russia - Stop Bypass (Portable)
color 0C

echo.
echo ======================================================================
echo           H1Z1 ROTK Russia - Stopping Bypass (Portable)
echo ======================================================================
echo.

set "STOPPED=0"

if not exist "%PID_FILE%" goto check_stopped
for /f "usebackq delims=" %%P in ("%PID_FILE%") do set "TARGET_PID=%%P"
if not defined TARGET_PID goto clear_pid

:: Validate PID and path before terminating
powershell -NoProfile -Command "$exp = [System.IO.Path]::GetFullPath('%EXPECTED_EXE%'); $p = Get-Process -Id ([int]'%TARGET_PID%') -ErrorAction SilentlyContinue; if ($null -ne $p -and [System.IO.Path]::GetFullPath($p.Path) -eq $exp) { Stop-Process -Id $p.Id -Force; $p.WaitForExit(3000) | Out-Null; exit 0 } else { exit 1 }"
if %errorlevel% equ 0 (
    echo  [*] Terminated project winws process [PID: %TARGET_PID%]
    set "STOPPED=1"
) else (
    echo  [*] Tracked PID was not active or belonged to a different process.
)

:clear_pid
if exist "%PID_FILE%" del /f /q "%PID_FILE%" >nul 2>&1

:check_stopped
if "%STOPPED%"=="0" echo  [*] No tracked active winws process found for this portable folder.

:: Safe driver isolation check: only stop WinDivert if NO OTHER winws is running on the system
echo  [*] Checking driver service isolation...
powershell -NoProfile -Command "$exp = [System.IO.Path]::GetFullPath('%EXPECTED_EXE%'); $others = @(Get-Process -Name 'winws' -ErrorAction SilentlyContinue | Where-Object { try { [System.IO.Path]::GetFullPath($_.Path) -ne $exp } catch { $true } }); $gdpi = Get-Process -Name 'goodbyedpi' -ErrorAction SilentlyContinue; if ($others.Count -eq 0 -and $null -eq $gdpi) { for ($i = 0; $i -lt 4; $i++) { sc.exe stop windivert > $null 2>&1; if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1060 -or $LASTEXITCODE -eq 1062) { break }; Start-Sleep -Milliseconds 500 } }" >nul 2>&1

echo.
echo  [OK] Project bypass is STOPPED.
echo.
ping 127.0.0.1 -n 2 >nul
exit /b 0

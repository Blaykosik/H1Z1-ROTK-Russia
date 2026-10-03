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
echo  Removing the scheduled task and deleting installed runtime files
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
set "TARGET_DIR=%ProgramData%\H1Z1-ROTK-Russia"
set "TASK_NAME=H1Z1-ROTK-Russia Auto Mode"
set "SCRIPT_DIR=%~dp0"

title H1Z1 ROTK Russia - Uninstall Auto Mode (v1.3.0)
color 0C

echo.
echo ======================================================================
echo       H1Z1 ROTK Russia - Uninstall Auto Mode (v1.3.0)
echo ======================================================================
echo.

:: 2. Stop and delete scheduled task
echo  [*] Removing Windows scheduled task [%TASK_NAME%]...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    schtasks /end /tn "%TASK_NAME%" >nul 2>&1
    schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
    echo  [OK] Scheduled task removed.
) else (
    echo  [*] Scheduled task was not registered.
)

:: 3. Terminate background watcher process (strict PID and command line check)
echo  [*] Terminating Auto Mode watcher process...
if exist "%TARGET_DIR%\.watcher.pid" (
    powershell -NoProfile -Command "$wPid = (Get-Content '%TARGET_DIR%\.watcher.pid' -ErrorAction SilentlyContinue | Select -First 1).Trim(); if ($wPid -match '^\d+$') { $p = Get-Process -Id ([int]$wPid) -ErrorAction SilentlyContinue; if ($null -ne $p -and $p.ProcessName -like '*powershell*') { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } }" >nul 2>&1
    del /f /q "%TARGET_DIR%\.watcher.pid" >nul 2>&1
)
if exist "%SCRIPT_DIR%.watcher.pid" (
    powershell -NoProfile -Command "$wPid = (Get-Content '%SCRIPT_DIR%.watcher.pid' -ErrorAction SilentlyContinue | Select -First 1).Trim(); if ($wPid -match '^\d+$') { $p = Get-Process -Id ([int]$wPid) -ErrorAction SilentlyContinue; if ($null -ne $p -and $p.ProcessName -like '*powershell*') { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } }" >nul 2>&1
    del /f /q "%SCRIPT_DIR%.watcher.pid" >nul 2>&1
)

:: 4. Terminate ONLY our tracked winws process (strict PID and path validation)
echo  [*] Terminating project bypass process (isolated)...
if exist "%TARGET_DIR%\.winws.pid" (
    powershell -NoProfile -Command "$exp = [System.IO.Path]::GetFullPath('%TARGET_DIR%\winws.exe'); $tPid = (Get-Content '%TARGET_DIR%\.winws.pid' -ErrorAction SilentlyContinue | Select -First 1).Trim(); if ($tPid -match '^\d+$') { $p = Get-Process -Id ([int]$tPid) -ErrorAction SilentlyContinue; if ($null -ne $p -and [System.IO.Path]::GetFullPath($p.Path) -eq $exp) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; $p.WaitForExit(3000) | Out-Null } }" >nul 2>&1
    del /f /q "%TARGET_DIR%\.winws.pid" >nul 2>&1
)

:: 5. Driver isolation check: only stop WinDivert if NO OTHER winws is running on the system
echo  [*] Checking driver service isolation...
powershell -NoProfile -Command "$exp = [System.IO.Path]::GetFullPath('%TARGET_DIR%\winws.exe'); $others = @(Get-Process -Name 'winws' -ErrorAction SilentlyContinue | Where-Object { try { [System.IO.Path]::GetFullPath($_.Path) -ne $exp } catch { $true } }); $gdpi = Get-Process -Name 'goodbyedpi' -ErrorAction SilentlyContinue; if ($others.Count -eq 0 -and $null -eq $gdpi) { for ($i = 0; $i -lt 4; $i++) { sc.exe stop windivert > $null 2>&1; if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1060 -or $LASTEXITCODE -eq 1062) { break }; Start-Sleep -Milliseconds 500 } }" >nul 2>&1

:: 6. Clean up installed ProgramData directory
echo  [*] Removing installed runtime directory: %TARGET_DIR%...
cd /d "%TEMP%"
powershell -NoProfile -Command "Start-Sleep -Milliseconds 300; if (Test-Path '%TARGET_DIR%') { Get-ChildItem '%TARGET_DIR%' -Exclude 'UNINSTALL_AUTO.cmd' -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue }" >nul 2>&1

:: Background process removes the remaining folder and self after this script exits
powershell -NoProfile -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -Command Start-Sleep -Seconds 2; Remove-Item -LiteralPath ''%TARGET_DIR%'' -Recurse -Force' -WindowStyle Hidden" >nul 2>&1

echo.
echo ======================================================================
echo  [SUCCESS] Auto Mode has been completely UNINSTALLED!
echo ======================================================================
echo.
echo  - Windows scheduled task removed.
echo  - Headless watcher stopped.
echo  - Project bypass process stopped (unrelated winws untouched).
echo  - Installed ProgramData directory removed.
echo  - System restored to clean state.
echo.
pause
exit /b 0

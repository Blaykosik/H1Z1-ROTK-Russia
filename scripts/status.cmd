@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "ROOT_DIR=%CD%"
popd
set "BIN_DIR=%ROOT_DIR%\bin"
set "PID_FILE=%BIN_DIR%\.winws.pid"

title H1Z1 ROTK Russia - Status
color 0B

echo.
echo ======================================================================
echo           H1Z1 ROTK Russia - Status Diagnostic
echo ======================================================================
echo.
echo  Project Version   : v1.0.0
echo  Engine            : winws (zapret v72.13 x86_64) + WinDivert
echo.

set "IS_ACTIVE=0"

if not exist "%PID_FILE%" goto show_status
for /f "usebackq delims=" %%P in ("%PID_FILE%") do set "ACTIVE_PID=%%P"
if not defined ACTIVE_PID goto show_status

powershell -NoProfile -Command "$p = Get-Process -Id %ACTIVE_PID% -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like '*winws*' }; if ($p) { exit 0 } else { exit 1 }"
if %errorlevel% equ 0 set "IS_ACTIVE=1"

:show_status
if "%IS_ACTIVE%"=="1" goto show_active

echo  Overall Status    : INACTIVE [NOT RUNNING]
goto show_driver

:show_active
echo  Overall Status    : ACTIVE [PROTECTING]
echo  Process PID       : %ACTIVE_PID%
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

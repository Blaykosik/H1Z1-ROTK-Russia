# Packaging script for H1Z1-ROTK-Russia v1.2.1
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$distDir  = Join-Path $repoRoot "dist"
$stageDir = Join-Path $distDir "stage\H1Z1-ROTK-Russia"
$zipPath  = Join-Path $distDir "H1Z1-ROTK-Russia-v1.2.1.zip"

Write-Host "=================================================="
Write-Host " Building H1Z1-ROTK-Russia v1.2.1 Release ZIP"
Write-Host "=================================================="

# 1. Clean previous build artifacts
if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force }
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

# 2. Create target directory tree
$runtimeDir = Join-Path $stageDir "_runtime"
$licenseDir = Join-Path $runtimeDir "licenses"
New-Item -ItemType Directory -Path $licenseDir -Force | Out-Null

# 3. Copy root action files
Write-Host "[*] Copying root action scripts..."
Copy-Item "$repoRoot\START.cmd"          -Destination "$stageDir\START.cmd"
Copy-Item "$repoRoot\STOP.cmd"           -Destination "$stageDir\STOP.cmd"
Copy-Item "$repoRoot\STATUS.cmd"         -Destination "$stageDir\STATUS.cmd"
Copy-Item "$repoRoot\INSTALL_AUTO.cmd"   -Destination "$stageDir\INSTALL_AUTO.cmd"
Copy-Item "$repoRoot\UNINSTALL_AUTO.cmd" -Destination "$stageDir\UNINSTALL_AUTO.cmd"

# Generate compact bilingual README.txt for the release ZIP
$readmeTxt = @"
======================================================================
               H1Z1 ROTK Russia - Direct UDP Bypass v1.2.1
======================================================================

QUICK START / БЫСТРЫЙ СТАРТ:

[EN]
OPTION A: AUTO MODE (RECOMMENDED - INSTALLED TO PROGRAMDATA)
1. Right-click INSTALL_AUTO.cmd -> "Run as administrator".
2. Copies runtime to %ProgramData%\H1Z1-ROTK-Russia and registers
   a logon background task.
3. You can now safely move or delete the downloaded release folder!
4. The bypass activates automatically when H1Z1 starts,
   and unloads automatically 7 seconds after H1Z1 exits.
5. Check status at any time with STATUS.cmd.
6. To uninstall, run UNINSTALL_AUTO.cmd from here or from
   %ProgramData%\H1Z1-ROTK-Russia\UNINSTALL_AUTO.cmd.

OPTION B: MANUAL MODE (100% PORTABLE)
1. Right-click START.cmd -> "Run as administrator".
2. Runs directly from this folder without installing anything.
3. Launch ROTK normally and play!
4. When finished, press any key in START window or run STOP.cmd.

[RU]
ВАРИАНТ А: АВТОРЕЖИМ (РЕКОМЕНДУЕТСЯ - УСТАНОВКА В PROGRAMDATA)
1. Нажмите правой кнопкой мыши по INSTALL_AUTO.cmd -> "Запуск от имени администратора".
2. Скрипт копирует рантайм в %ProgramData%\H1Z1-ROTK-Russia и регистрирует
   фоновую задачу автозапуска.
3. После этого исходную скачанную папку можно безопасно переместить или удалить!
4. Обход включается автоматически при запуске H1Z1,
   и выключается автоматически через 7 секунд после закрытия игры.
5. Проверить текущее состояние можно через STATUS.cmd.
6. Для удаления запустите UNINSTALL_AUTO.cmd от администратора (из этой папки
   или из %ProgramData%\H1Z1-ROTK-Russia\UNINSTALL_AUTO.cmd).

ВАРИАНТ Б: РУЧНОЙ РЕЖИМ (100% ПОРТАТИВНЫЙ)
1. Нажмите правой кнопкой мыши по START.cmd -> "Запуск от имени администратора".
2. Работает прямо из этой папки без какой-либо установки в систему.
3. Запустите ROTK и играйте!
4. После завершения игры нажмите любую клавишу в окне START или запустите STOP.cmd.

----------------------------------------------------------------------
SECURITY, TRUST & PRIVACY / БЕЗОПАСНОСТЬ И ПРИВАТНОСТЬ:
- Not a cheat or injector: does not touch game memory, files, or BattlEye.
- Game-specific zapret/winws profile with narrow ROTK UDP filter scope.
- Zero telemetry, zero credentials, no remote servers, no hidden web calls.

- Не чит и не инжектор: не трогает память, файлы игры и не вмешивается в BattlEye.
- Узкий профиль zapret/winws исключительно для UDP-трафика серверов ROTK.
- Ноль телеметрии, ноль сбора паролей, нет своих серверов или скрытых запросов.

Documentation & Source Code / Документация и исходный код:
https://github.com/Blaykosik/H1Z1-ROTK-Russia
======================================================================
"@
[System.IO.File]::WriteAllText("$stageDir\README.txt", $readmeTxt, [System.Text.Encoding]::UTF8)

# 4. Copy runtime binaries and scripts into _runtime/
Write-Host "[*] Copying binaries and runtime files into _runtime/..."
Copy-Item "$repoRoot\bin\winws.exe"        -Destination "$runtimeDir\winws.exe"
Copy-Item "$repoRoot\bin\WinDivert.dll"    -Destination "$runtimeDir\WinDivert.dll"
Copy-Item "$repoRoot\bin\WinDivert64.sys"  -Destination "$runtimeDir\WinDivert64.sys"
Copy-Item "$repoRoot\bin\cygwin1.dll"      -Destination "$runtimeDir\cygwin1.dll"
Copy-Item "$repoRoot\bin\stun.bin"         -Destination "$runtimeDir\stun.bin"
Copy-Item "$repoRoot\scripts\watcher.ps1"  -Destination "$runtimeDir\watcher.ps1"
Copy-Item "$repoRoot\config\filter.txt"    -Destination "$runtimeDir\filter.txt"
Copy-Item "$repoRoot\UNINSTALL_AUTO.cmd"   -Destination "$runtimeDir\UNINSTALL_AUTO.cmd"
Copy-Item "$repoRoot\STATUS.cmd"           -Destination "$runtimeDir\STATUS.cmd"

# Create release-specific rotk_winws.conf pointing directly to @filter.txt in current folder
$confContent = @(
    "--wf-raw=@filter.txt",
    "--dpi-desync=fake",
    "--dpi-desync-any-protocol=1",
    "--dpi-desync-fake-unknown-udp=stun.bin",
    "--dpi-desync-cutoff=d2"
) -join "`r`n"
Set-Content -Path "$runtimeDir\rotk_winws.conf" -Value $confContent -Encoding ascii

# 5. Copy license files into _runtime/licenses/
Write-Host "[*] Copying licenses into _runtime/licenses/..."
Copy-Item "$repoRoot\LICENSES\LICENSE.cygwin.txt"    -Destination "$licenseDir\LICENSE.cygwin.txt"
Copy-Item "$repoRoot\LICENSES\LICENSE.windivert.txt" -Destination "$licenseDir\LICENSE.windivert.txt"
Copy-Item "$repoRoot\LICENSES\LICENSE.zapret.txt"    -Destination "$licenseDir\LICENSE.zapret.txt"

# 6. Create ZIP archive inside dist/
Write-Host "[*] Compressing release package to $zipPath..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $distDir "stage"), $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

# 7. Compute SHA256 checksums and generate SHA256SUMS.txt in dist/
$zipHash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
Write-Host "[*] Release ZIP SHA256: $zipHash"

$sumsContent = @(
    "# Release Archive (v1.2.1 Stable):",
    "$zipHash  H1Z1-ROTK-Russia-v1.2.1.zip",
    "",
    "# Bundled Runtime Binaries (bin/):",
    "$((Get-FileHash "$repoRoot\bin\winws.exe" -Algorithm SHA256).Hash)  bin/winws.exe",
    "$((Get-FileHash "$repoRoot\bin\WinDivert.dll" -Algorithm SHA256).Hash)  bin/WinDivert.dll",
    "$((Get-FileHash "$repoRoot\bin\WinDivert64.sys" -Algorithm SHA256).Hash)  bin/WinDivert64.sys",
    "$((Get-FileHash "$repoRoot\bin\cygwin1.dll" -Algorithm SHA256).Hash)  bin/cygwin1.dll",
    "$((Get-FileHash "$repoRoot\bin\stun.bin" -Algorithm SHA256).Hash)  bin/stun.bin"
) -join "`r`n"
Set-Content -Path (Join-Path $distDir "SHA256SUMS.txt") -Value $sumsContent -Encoding ascii
Write-Host "[*] Generated SHA256SUMS.txt in $distDir"

Write-Host "=================================================="
Write-Host " Build Complete!"
Write-Host "=================================================="

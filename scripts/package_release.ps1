# Packaging script for H1Z1-ROTK-Russia v1.2.1
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$distDir  = Join-Path $repoRoot "dist"
$stageDir = Join-Path $distDir "stage\H1Z1-ROTK-Russia"
$zipPath  = Join-Path $repoRoot "H1Z1-ROTK-Russia-v1.2.1.zip"

Write-Host "=================================================="
Write-Host " Building H1Z1-ROTK-Russia v1.2.1 Release ZIP"
Write-Host "=================================================="

# 1. Clean previous build artifacts
if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force }
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

# 2. Create target directory tree
$runtimeDir = Join-Path $stageDir "_runtime"
$licenseDir = Join-Path $runtimeDir "licenses"
New-Item -ItemType Directory -Path $licenseDir -Force | Out-Null

# 3. Copy root action files
Write-Host "[*] Copying root action scripts and README..."
Copy-Item "$repoRoot\START.cmd"          -Destination "$stageDir\START.cmd"
Copy-Item "$repoRoot\STOP.cmd"           -Destination "$stageDir\STOP.cmd"
Copy-Item "$repoRoot\STATUS.cmd"         -Destination "$stageDir\STATUS.cmd"
Copy-Item "$repoRoot\INSTALL_AUTO.cmd"   -Destination "$stageDir\INSTALL_AUTO.cmd"
Copy-Item "$repoRoot\UNINSTALL_AUTO.cmd" -Destination "$stageDir\UNINSTALL_AUTO.cmd"
Copy-Item "$repoRoot\README.txt"         -Destination "$stageDir\README.txt"

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
Copy-Item "$repoRoot\BINARY_PROVENANCE.md" -Destination "$runtimeDir\BINARY_PROVENANCE.md"

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

# 6. Create ZIP archive
Write-Host "[*] Compressing release package to $zipPath..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $distDir "stage"), $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

# 7. Compute SHA256 checksums
$zipHash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
Write-Host "[*] Release ZIP SHA256: $zipHash"

Write-Host "=================================================="
Write-Host " Build Complete!"
Write-Host "=================================================="

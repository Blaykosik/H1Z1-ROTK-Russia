# H1Z1 ROTK Russia - Event-Driven Process Watcher (v1.3.0)
# Automatically manages the life-cycle of the direct UDP bypass based on H1Z1.exe.
# Strictly isolated: only controls this project's own winws instance; never touches unrelated tools.

$ErrorActionPreference = "Stop"

# Determine runtime directories
$scriptDir = $PSScriptRoot
if (Test-Path "$scriptDir\_runtime\winws.exe") {
    $runtimeDir = "$scriptDir\_runtime"
    $binDir     = $runtimeDir
    $configDir  = $runtimeDir
} elseif (Test-Path "$scriptDir\..\bin\winws.exe") {
    $binDir     = (Resolve-Path "$scriptDir\..\bin").Path
    $configDir  = (Resolve-Path "$scriptDir\..\config").Path
} elseif (Test-Path "$scriptDir\winws.exe") {
    $runtimeDir = $scriptDir
    $binDir     = $runtimeDir
    $configDir  = $runtimeDir
} elseif (Test-Path "$scriptDir\bin\winws.exe") {
    $binDir     = "$scriptDir\bin"
    $configDir  = "$scriptDir\config"
} else {
    $binDir     = "$scriptDir\bin"
    $configDir  = "$scriptDir\config"
}

$pidFile           = "$binDir\.winws.pid"
$watcherPidFile    = "$binDir\.watcher.pid"
$lastErrFile       = "$binDir\.last_start_error.txt"
$confFile          = "$configDir\rotk_winws.conf"
$expectedWinwsPath = [System.IO.Path]::GetFullPath("$binDir\winws.exe")

# Record Watcher process ID
try {
    $PID | Out-File -FilePath $watcherPidFile -Encoding ascii -Force
} catch {}

function Is-GameRunning {
    $procs = Get-Process -Name "H1Z1" -ErrorAction SilentlyContinue
    return ($null -ne $procs -and $procs.Count -gt 0)
}

function Get-TrackedBypassProcess {
    if (-not (Test-Path $pidFile)) { return $null }
    try {
        $rawPid = (Get-Content $pidFile -ErrorAction Stop | Select-Object -First 1).Trim()
        if ($rawPid -match '^\d+$') {
            $targetId = [int]$rawPid
            $p = Get-Process -Id $targetId -ErrorAction SilentlyContinue
            if ($null -ne $p -and $p.ProcessName -like "*winws*") {
                $pPath = try { [System.IO.Path]::GetFullPath($p.Path) } catch { "" }
                if ($pPath -eq $expectedWinwsPath) {
                    return $p
                }
            }
        }
    } catch {}
    return $null
}

function Is-BypassRunning {
    return ($null -ne (Get-TrackedBypassProcess))
}

function Write-StartFailure([string]$Stage, [int]$Code) {
    # Consumed by STATUS.cmd / DIAGNOSE.cmd to explain why Auto Mode could not start winws.
    try { ("{0};stage={1};code={2};source=WATCHER" -f (Get-Date -Format s), $Stage, $Code) | Out-File -FilePath $lastErrFile -Encoding ascii -Force } catch {}
}

function Start-Bypass {
    if (Is-BypassRunning) { return }
    
    # Clean up any stale pid file
    if (Test-Path $pidFile) { Remove-Item $pidFile -Force -ErrorAction SilentlyContinue }

    # Start our winws minimized
    try {
        $proc = Start-Process -FilePath $expectedWinwsPath -ArgumentList "@$confFile" -WorkingDirectory $binDir -WindowStyle Minimized -PassThru -ErrorAction Stop
    } catch {
        $e = $_.Exception
        while ($e -and -not ($e -is [System.ComponentModel.Win32Exception])) { $e = $e.InnerException }
        Write-StartFailure 'launch' $(if ($e) { $e.NativeErrorCode } else { -1 })
        return
    }

    # winws exits at once with the Win32 error code when WinDivertOpen fails; watch it briefly.
    $null = $proc.Handle
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $proc.HasExited -and $sw.ElapsedMilliseconds -lt 2500) { Start-Sleep -Milliseconds 250 }
    if ($proc.HasExited) {
        Write-StartFailure 'driver' $proc.ExitCode
        return
    }
    $proc.Id | Out-File -FilePath $pidFile -Encoding ascii -Force
    if (Test-Path $lastErrFile) { Remove-Item $lastErrFile -Force -ErrorAction SilentlyContinue }
}

function Stop-Bypass {
    # Stop ONLY our tracked process
    $p = Get-TrackedBypassProcess
    if ($null -ne $p) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        # The driver can only be unloaded after winws has really exited and closed its handle.
        try { $p.WaitForExit(3000) | Out-Null } catch {}
    }
    if (Test-Path $pidFile) {
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }
    
    # Isolation safety check: only unhook WinDivert driver if NO other winws or known tool is running
    $allWinws = Get-Process -Name "winws" -ErrorAction SilentlyContinue
    $otherWinws = @($allWinws | Where-Object { 
        try { [System.IO.Path]::GetFullPath($_.Path) -ne $expectedWinwsPath } catch { $true }
    })
    
    if ($otherWinws.Count -eq 0) {
        $gdpi = Get-Process -Name "goodbyedpi" -ErrorAction SilentlyContinue
        if ($null -eq $gdpi) {
            for ($i = 0; $i -lt 4; $i++) {
                & sc.exe stop windivert > $null 2>&1
                # 0 = stop accepted, 1060 = no such service, 1062 = not started
                if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1060 -or $LASTEXITCODE -eq 1062) { break }
                Start-Sleep -Milliseconds 500
            }
        }
    }
}

# Cleanup on exit
$cleanupBlock = {
    Stop-Bypass
    if (Test-Path $watcherPidFile) {
        Remove-Item $watcherPidFile -Force -ErrorAction SilentlyContinue
    }
}

# Initial synchronization
if (Is-GameRunning) {
    Start-Bypass
    $state = "RUNNING"
} else {
    Stop-Bypass
    $state = "STOPPED"
}

# Initialize WMI event queries for H1Z1.exe start & stop
$startQuery = New-Object System.Management.WqlEventQuery("SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName = 'H1Z1.exe'")
$startWatcher = New-Object System.Management.ManagementEventWatcher($startQuery)
$startWatcher.Options.Timeout = [TimeSpan]::FromSeconds(5)

$stopQuery = New-Object System.Management.WqlEventQuery("SELECT * FROM Win32_ProcessStopTrace WHERE ProcessName = 'H1Z1.exe'")
$stopWatcher = New-Object System.Management.ManagementEventWatcher($stopQuery)
$stopWatcher.Options.Timeout = [TimeSpan]::FromSeconds(5)

try {
    while ($true) {
        if ($state -eq "STOPPED") {
            try {
                $null = $startWatcher.WaitForNextEvent()
                if (Is-GameRunning) {
                    Start-Bypass
                    $state = "RUNNING"
                }
            } catch {
                # 5s safety reconciliation: verify state in case event was missed
                if (Is-GameRunning) {
                    Start-Bypass
                    $state = "RUNNING"
                }
            }
        } elseif ($state -eq "RUNNING") {
            try {
                $null = $stopWatcher.WaitForNextEvent()
                # Game process stopped: apply grace period of 7 seconds to protect against quick client restart
                Start-Sleep -Seconds 7
                if (-not (Is-GameRunning)) {
                    Stop-Bypass
                    $state = "STOPPED"
                }
            } catch {
                # 5s safety reconciliation: verify if game exited without stop event
                if (-not (Is-GameRunning)) {
                    Start-Sleep -Seconds 2
                    if (-not (Is-GameRunning)) {
                        Stop-Bypass
                        $state = "STOPPED"
                    }
                }
            }
        }
    }
} finally {
    & $cleanupBlock
}

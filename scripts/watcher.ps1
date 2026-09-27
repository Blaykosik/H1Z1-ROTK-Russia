# H1Z1 ROTK Russia - Event-Driven Process Watcher (v1.2.0)
# Automatically manages the life-cycle of the direct UDP bypass based on H1Z1.exe.

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
} else {
    $binDir     = "$scriptDir\bin"
    $configDir  = "$scriptDir\config"
}

$pidFile        = "$binDir\.winws.pid"
$watcherPidFile = "$binDir\.watcher.pid"
$confFile       = "$configDir\rotk_winws.conf"

# Record Watcher process ID
try {
    $PID | Out-File -FilePath $watcherPidFile -Encoding ascii -Force
} catch {}

function Is-GameRunning {
    $procs = Get-Process -Name "H1Z1" -ErrorAction SilentlyContinue
    return ($null -ne $procs -and $procs.Count -gt 0)
}

function Is-BypassRunning {
    $procs = Get-Process -Name "winws" -ErrorAction SilentlyContinue
    return ($null -ne $procs -and $procs.Count -gt 0)
}

function Start-Bypass {
    if (Is-BypassRunning) { return }
    
    # Clean up any stale pid file
    if (Test-Path $pidFile) { Remove-Item $pidFile -Force -ErrorAction SilentlyContinue }

    # Start winws minimized
    $proc = Start-Process -FilePath "$binDir\winws.exe" -ArgumentList "@$confFile" -WorkingDirectory $binDir -WindowStyle Minimized -PassThru
    Start-Sleep -Milliseconds 800
    if ($proc -and (-not $proc.HasExited)) {
        $proc.Id | Out-File -FilePath $pidFile -Encoding ascii -Force
    }
}

function Stop-Bypass {
    if (Test-Path $pidFile) {
        try {
            $savedPid = (Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
            if ($savedPid -match '^\d+$') {
                Stop-Process -Id [int]$savedPid -Force -ErrorAction SilentlyContinue
            }
        } catch {}
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }
    
    # Ensure any winws process is terminated
    Get-Process -Name "winws" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Safely unhook WinDivert driver
    & sc.exe stop windivert > $null 2>&1
    & sc.exe delete windivert > $null 2>&1
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
            } catch [System.Management.ManagementException] {
                # 5s timeout tick: verify state in case event was missed
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
            } catch [System.Management.ManagementException] {
                # 5s timeout tick: verify if game exited without stop event
                if (-not (Is-GameRunning)) {
                    Start-Sleep -Seconds 7
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

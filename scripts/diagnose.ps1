# H1Z1 ROTK Russia - Self-Diagnostics Engine (v1.3.0)
#
# READ-ONLY. This script never installs, stops or deletes drivers or services, never changes
# routes, firewall, Defender or VPN settings and never terminates processes. It only observes
# the system and explains what it sees. The single active operation is an optional 15-second
# pktmon packet capture (Full mode, only while H1Z1.exe is running) that is used to find the
# real ROTK endpoints. The capture file is parsed locally and deleted immediately.
#
# Modes:
#   Full      - complete diagnosis + sanitized diagnostic-report.txt (DIAGNOSE.cmd)
#   Status    - fast state overview (STATUS.cmd)
#   Startup   - explain why winws.exe failed to start (START.cmd / watcher)
#   Preflight - installation readiness checks (INSTALL_AUTO.cmd)
#   SanitizerTest - self-test of the report sanitizer (used by scripts/test_report_privacy.ps1)

[CmdletBinding()]
param(
    [ValidateSet('Full', 'Status', 'Startup', 'Preflight', 'SanitizerTest')]
    [string]$Mode = 'Full',
    [string]$ReportDir = '',
    [int]$CaptureSeconds = 15,
    [switch]$NoCapture,
    [string]$StartupStage = '',
    [int]$StartupCode = -1
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$ProjectVersion = 'v1.3.0'
$TaskName       = 'H1Z1-ROTK-Russia Auto Mode'
$InstallDir     = Join-Path $env:ProgramData 'H1Z1-ROTK-Russia'
$KnownLoginIP   = '162.19.94.95'
$KnownMatchIP   = '162.19.126.1'      # representative address of the known match pool 162.19.126.0/24
$RotkSupernet   = @('162.19.0.0', '162.19.255.255')

# SHA-256 of the unmodified runtime binaries shipped with this release.
$ExpectedHashes = @{
    'winws.exe'       = 'A14BFF1DF6234EA555D2E0C61B589F0707C0B12D6C9B7EECCDA76012154996E8'
    'WinDivert.dll'   = 'C1E060EE19444A259B2162F8AF0F3FE8C4428A1C6F694DCE20DE194AC8D7D9A2'
    'WinDivert64.sys' = '8DA085332782708D8767BCACE5327A6EC7283C17CFB85E40B03CD2323A90DDC2'
    'cygwin1.dll'     = '103104A52E5293CE418944725DF19E2BF81AD9269B9A120D71D39028E821499B'
    'stun.bin'        = '9CD5469309780CA56C0BD97266524A48C7EE529D02C3179CFECB20B260A59641'
}
$RuntimeFiles = @('winws.exe', 'WinDivert.dll', 'WinDivert64.sys', 'cygwin1.dll', 'stun.bin')

# Windows error codes that WinDivertOpen (and therefore winws.exe, whose exit code is the
# Win32 error) reports in practice, with a human explanation and a suggested action.
$ErrorKB = @{
    2    = @('ERROR_FILE_NOT_FOUND', 'Windows could not find the WinDivert driver file it was told to load.',
             'Most often a leftover "WinDivert" service from another tool (old zapret/GoodbyeDPI folder) points to a folder that no longer exists, or antivirus removed WinDivert64.sys. See the WinDivert section of this report.')
    3    = @('ERROR_PATH_NOT_FOUND', 'Windows could not find the folder of the WinDivert driver it was told to load.',
             'A leftover "WinDivert" service from another tool or an older copy points to a folder that no longer exists. See the WinDivert section of this report.')
    5    = @('ERROR_ACCESS_DENIED', 'Windows denied access while loading the WinDivert driver.',
             'Run as administrator. If you already do, security software is blocking driver loading.')
    87   = @('ERROR_INVALID_PARAMETER', 'WinDivert rejected the filter or the loaded driver is a different WinDivert version.',
             'Another tool may have loaded its own WinDivert driver version. Close it and reboot, then try again.')
    225  = @('ERROR_VIRUS_INFECTED', 'Windows Defender (or another antivirus) blocked the file as a threat.',
             'Restore the file from quarantine and add an exclusion for the project folder, or re-download the release.')
    226  = @('ERROR_VIRUS_DELETED', 'Antivirus deleted the file.',
             'Restore the file from quarantine and add an exclusion for the project folder, or re-download the release.')
    577  = @('ERROR_INVALID_IMAGE_HASH', 'Windows Code Integrity refused the driver signature.',
             'The driver file may be damaged or blocked by a Code Integrity policy. Re-download the release; check the Code Integrity events listed in this report.')
    654  = @('ERROR_DRIVER_FAILED_PRIOR_UNLOAD', 'A previous WinDivert driver instance is still pending unload (often a different version used by another tool).',
             'Close other WinDivert-based tools and reboot Windows.')
    1058 = @('ERROR_SERVICE_DISABLED', 'The WinDivert service record exists but is disabled.',
             'A stale WinDivert service record blocks loading. Reboot Windows; if it persists, remove the stale record (see WinDivert section).')
    1072 = @('ERROR_SERVICE_MARKED_FOR_DELETE', 'The WinDivert service is marked for deletion and cannot be started again yet.',
             'Close services.msc / Process Hacker style tools and reboot Windows.')
    1260 = @('ERROR_ACCESS_DISABLED_BY_POLICY', 'A Windows policy blocked the program from running.',
             'Group Policy / AppLocker / Smart App Control blocks winws.exe. Allow it or use a PC without this policy.')
    1275 = @('ERROR_DRIVER_BLOCKED', 'Windows blocked the WinDivert driver from loading.',
             'Usually the Microsoft vulnerable driver blocklist, Memory Integrity (HVCI) policy or security software. See Code Integrity events in this report.')
    1753 = @('EPT_S_NOT_REGISTERED', 'The Base Filtering Engine (BFE) service is not running.',
             'Enable and start the "Base Filtering Engine" Windows service (it is required by Windows Firewall and WinDivert).')
    4551 = @('ERROR_SYSTEM_INTEGRITY_POLICY_VIOLATION', 'Windows Defender Application Control / Smart App Control blocked the file.',
             'Smart App Control blocks unsigned programs such as winws.exe. It can only be turned off in Windows Security > App & browser control.')
}

# --------------------------------------------------------------------------------------------
# Output, checks and sanitization
# --------------------------------------------------------------------------------------------
$script:Lines      = New-Object System.Collections.Generic.List[string]
$script:Checks     = New-Object System.Collections.Generic.List[object]
$script:AllowedIPs = New-Object 'System.Collections.Generic.HashSet[string]'
$script:SafeTokens = New-Object 'System.Collections.Generic.HashSet[string]'
$script:LocalPublicIPs = New-Object 'System.Collections.Generic.HashSet[string]'
$script:PathMap    = New-Object System.Collections.Generic.List[object]
$script:Verdict    = $null

foreach ($h in $ExpectedHashes.Values) { [void]$script:SafeTokens.Add($h) }

function Add-PathMapping([string]$From, [string]$To) {
    if ([string]::IsNullOrWhiteSpace($From)) { return }
    $f = $From.TrimEnd('\')
    if ($f.Length -lt 3) { return }
    $script:PathMap.Add([pscustomobject]@{ From = $f; To = $To })
}

function Test-PrivateIPv4([string]$ip) {
    $o = $ip.Split('.') | ForEach-Object { [int]$_ }
    if ($o[0] -eq 10 -or $o[0] -eq 127 -or $o[0] -eq 0) { return $true }
    if ($o[0] -eq 172 -and $o[1] -ge 16 -and $o[1] -le 31) { return $true }
    if ($o[0] -eq 192 -and $o[1] -eq 168) { return $true }
    if ($o[0] -eq 169 -and $o[1] -eq 254) { return $true }
    if ($o[0] -eq 100 -and $o[1] -ge 64 -and $o[1] -le 127) { return $true }   # carrier-grade NAT
    if ($o[0] -ge 224) { return $true }                                       # multicast / reserved
    return $false
}

function ConvertTo-UInt32IP([string]$ip) {
    $b = ([System.Net.IPAddress]::Parse($ip)).GetAddressBytes()
    [Array]::Reverse($b)
    return [BitConverter]::ToUInt32($b, 0)
}

function Test-IPInRange([string]$ip, [string]$lo, [string]$hi) {
    $v = ConvertTo-UInt32IP $ip
    return ($v -ge (ConvertTo-UInt32IP $lo) -and $v -le (ConvertTo-UInt32IP $hi))
}

function Protect-Text([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return $s }

    # Keep known-good tokens (release hashes) out of the generic secret scrubber.
    $vault = @{}
    $i = 0
    foreach ($t in $script:SafeTokens) {
        if ($s.IndexOf($t, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $key = "@@SAFE$i@@"; $vault[$key] = $t; $i++
            $s = [regex]::Replace($s, [regex]::Escape($t), $key, 'IgnoreCase')
        }
    }

    # Proxy share links, subscriptions and URLs.
    $s = [regex]::Replace($s, '(?i)\b(vless|vmess|trojan|ssr?|hysteria2?|hy2|tuic|wireguard|socks5?)://\S+', '<PROXY-URI>')
    $s = [regex]::Replace($s, '(?i)\bhttps?://[^\s"''<>]+', {
        param($m)
        if ($m.Value -match '(?i)^https?://(www\.)?github\.com/Blaykosik/') { return $m.Value }
        return '<URL>'
    })

    # Paths: known roots first, then any remaining absolute path keeps only its leaf name.
    foreach ($p in ($script:PathMap | Sort-Object { $_.From.Length } -Descending)) {
        $s = [regex]::Replace($s, [regex]::Escape($p.From), $p.To.Replace('$', '$$'), 'IgnoreCase')
    }
    $s = [regex]::Replace($s, '%USERPROFILE%\\(?:[^\\\r\n"<>|*?:]+\\)+', '%USERPROFILE%\...\')
    $s = [regex]::Replace($s, '(?i)(\\\?\?\\|\\\\\?\\)?\b[a-z]:\\(?:[^\\\r\n"<>|*?:]+\\)*([^\\\r\n"<>|*?:\s]*)', {
        param($m)
        $leaf = $m.Groups[2].Value
        if ($leaf) { return '<PATH>\' + $leaf }
        return '<PATH>'
    })

    # Identity: account, machine, SID, e-mail, Steam IDs, GUID/UUID values.
    foreach ($n in @($env:USERNAME, $env:COMPUTERNAME)) {
        if ($n -and $n.Length -ge 2) { $s = [regex]::Replace($s, '(?i)(?<![A-Za-z0-9])' + [regex]::Escape($n) + '(?![A-Za-z0-9])', '<ID>') }
    }
    if ($env:USERDOMAIN -and $env:USERDOMAIN -ne $env:COMPUTERNAME -and $env:USERDOMAIN -notmatch '^(WORKGROUP|NT AUTHORITY)$' -and $env:USERDOMAIN.Length -ge 2) {
        $s = [regex]::Replace($s, '(?i)(?<![A-Za-z0-9])' + [regex]::Escape($env:USERDOMAIN) + '(?![A-Za-z0-9])', '<ID>')
    }
    $s = [regex]::Replace($s, '\bS-1-5-21-[\d-]+\b', '<SID>')
    $s = [regex]::Replace($s, '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', '<EMAIL>')
    $s = [regex]::Replace($s, '\b7656119\d{10}\b', '<STEAMID>')
    $s = [regex]::Replace($s, '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b', '<UUID>')

    # Key/value secrets and long opaque tokens.
    $s = [regex]::Replace($s, '(?i)\b(pbk|sid|sni|uuid|password|passwd|pwd|token|ticket|session|secret|key|auth|cookie)\s*[=:]\s*[^\s;,&]+', '$1=<REDACTED>')
    $s = [regex]::Replace($s, '\b[A-Za-z0-9+/_-]{32,}={0,2}', {
        param($m)
        if ($m.Value -match '\d' -and $m.Value -match '[A-Za-z]') { return '<REDACTED>' }
        return $m.Value
    })

    # IPv6: everything except loopback is masked (global IPv6 addresses identify the user).
    $s = [regex]::Replace($s, '(?i)(?<![0-9a-z:])(?:[0-9a-f]{0,4}:){2,7}[0-9a-f]{0,4}(?:%\d+)?(?![0-9a-z:])', {
        param($m)
        $v = $m.Value
        $colons = ($v.ToCharArray() | Where-Object { $_ -eq ':' }).Count
        if ($v -eq '::1') { return $v }
        if ($v.Contains('::') -or $v -match '[a-fA-F]' -or $colons -ge 5) { return '<IPv6>' }
        return $v
    })

    # IPv4: private ranges and ROTK/observed server endpoints stay, everything else is masked.
    $s = [regex]::Replace($s, '(?<![\d.])(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?![\d]|\.\d)', {
        param($m)
        $ip = $m.Value
        foreach ($g in 1..4) { if ([int]$m.Groups[$g].Value -gt 255) { return $ip } }
        if ($script:LocalPublicIPs.Contains($ip)) { return '<LOCAL-PUBLIC-IP>' }
        if (Test-PrivateIPv4 $ip) { return $ip }
        if ($script:AllowedIPs.Contains($ip)) { return $ip }
        if (Test-IPInRange $ip $RotkSupernet[0] $RotkSupernet[1]) { return $ip }
        return ('{0}.{1}.x.x' -f $m.Groups[1].Value, $m.Groups[2].Value)
    })

    foreach ($k in $vault.Keys) { $s = $s.Replace($k, $vault[$k]) }
    return $s
}

function Out-Line([string]$Text = '', [string]$Color = 'Gray') {
    $safe = Protect-Text $Text
    $script:Lines.Add($safe)
    Write-Host $safe -ForegroundColor $Color
}

function Out-Section([string]$Title) {
    Out-Line ''
    Out-Line ('-- ' + $Title + ' ' + ('-' * [Math]::Max(2, 66 - $Title.Length))) 'Cyan'
}

function Out-KV([string]$Key, $Value, [string]$Color = 'Gray', [int]$Indent = 2) {
    Out-Line (('{0}{1,-22}: {2}' -f (' ' * $Indent), $Key, $Value)) $Color
}

function Add-Check([string]$Level, [string]$Name, [string]$Detail = '', [string]$Action = '') {
    $script:Checks.Add([pscustomobject]@{ Level = $Level; Name = $Name; Detail = $Detail; Action = $Action })
}

function Get-LevelColor([string]$Level) {
    switch ($Level) { 'OK' { 'Green' } 'WARN' { 'Yellow' } 'FAIL' { 'Red' } default { 'Gray' } }
}

function Get-ErrorText([int]$Code) {
    if ($ErrorKB.ContainsKey($Code)) { return ('{0} ({1}) - {2}' -f $Code, $ErrorKB[$Code][0], $ErrorKB[$Code][1]) }
    try { return ('{0} - {1}' -f $Code, (New-Object System.ComponentModel.Win32Exception($Code)).Message) } catch { return [string]$Code }
}

function Format-Path([string]$p) {
    if (-not $p) { return '' }
    return ($p -replace '^\\\?\?\\', '' -replace '^\\SystemRoot', $env:SystemRoot)
}

# --------------------------------------------------------------------------------------------
# Context: where are we running from and which runtimes exist
# --------------------------------------------------------------------------------------------
$script:IsAdmin = $false
try { $script:IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch {}

$scriptDir = $PSScriptRoot
$script:Runtimes = New-Object System.Collections.Generic.List[object]
$localRoot = $null

function New-Runtime([string]$Label, [string]$Bin, [string]$Config) {
    return [pscustomobject]@{
        Label  = $Label
        Bin    = $Bin
        Config = $Config
        Conf   = (Join-Path $Config 'rotk_winws.conf')
        Filter = (Join-Path $Config 'filter.txt')
        Exe    = (Join-Path $Bin 'winws.exe')
    }
}

if (Test-Path (Join-Path $scriptDir 'winws.exe')) {
    if ($scriptDir.TrimEnd('\') -ieq $InstallDir) {
        $localRoot = $InstallDir
    } else {
        $localRoot = Split-Path $scriptDir -Parent
        $script:Runtimes.Add((New-Runtime 'portable' $scriptDir $scriptDir))
    }
} elseif (Test-Path (Join-Path $scriptDir '..\bin\winws.exe')) {
    $localRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
    $script:Runtimes.Add((New-Runtime 'repository' (Join-Path $localRoot 'bin') (Join-Path $localRoot 'config')))
} else {
    $localRoot = $scriptDir
}
if (Test-Path (Join-Path $InstallDir 'winws.exe')) {
    $script:Runtimes.Add((New-Runtime 'auto-mode' $InstallDir $InstallDir))
}

# Path normalisation for the report (longest match wins inside Protect-Text).
Add-PathMapping $InstallDir '%ProgramData%\H1Z1-ROTK-Russia'
if ($localRoot -and $localRoot.TrimEnd('\') -ine $InstallDir) { Add-PathMapping $localRoot '<PROJECT>' }
Add-PathMapping $env:USERPROFILE '%USERPROFILE%'
Add-PathMapping $env:ProgramData '%ProgramData%'
Add-PathMapping $env:SystemRoot '%WINDIR%'
Add-PathMapping $env:ProgramFiles '%ProgramFiles%'
Add-PathMapping ${env:ProgramFiles(x86)} '%ProgramFiles(x86)%'
Add-PathMapping $env:TEMP '%TEMP%'

# Public IPv4 addresses configured directly on this PC (PPPoE / bridge setups) must never leak.
try {
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object {
        if (-not (Test-PrivateIPv4 $_.IPAddress)) { [void]$script:LocalPublicIPs.Add($_.IPAddress) }
    }
} catch {}

# --------------------------------------------------------------------------------------------
# Collectors
# --------------------------------------------------------------------------------------------
function Get-ProcessPathSafe($p) {
    try { if ($p.Path) { return $p.Path } } catch {}
    try { $c = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $p.Id) -ErrorAction Stop; return $c.ExecutablePath } catch {}
    return $null
}

function Get-WinwsInventory {
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($p in @(Get-Process -Name 'winws' -ErrorAction SilentlyContinue)) {
        $path = Get-ProcessPathSafe $p
        $owner = 'other'
        foreach ($rt in $script:Runtimes) {
            if ($path -and ([System.IO.Path]::GetFullPath($path) -ieq [System.IO.Path]::GetFullPath($rt.Exe))) { $owner = $rt.Label }
        }
        if (-not $path) { $owner = 'unknown (path not readable)' }
        $result.Add([pscustomobject]@{ Id = $p.Id; Path = $path; Owner = $owner })
    }
    return $result
}

function Get-TrackedPid($rt, [string]$Name) {
    $f = Join-Path $rt.Bin $Name
    if (-not (Test-Path $f)) { return $null }
    try {
        $raw = (Get-Content $f -ErrorAction Stop | Select-Object -First 1).Trim()
        if ($raw -match '^\d+$') { return [int]$raw }
    } catch {}
    return $null
}

function Get-LastStartRecord($rt) {
    $f = Join-Path $rt.Bin '.last_start_error.txt'
    if (-not (Test-Path $f)) { return $null }
    try {
        $raw = (Get-Content $f -ErrorAction Stop | Select-Object -First 1).Trim()
        $o = [ordered]@{ Raw = $raw; Time = ''; Stage = ''; Code = -1; Source = '' }
        foreach ($part in $raw.Split(';')) {
            if ($part -match '^\d{4}-\d{2}-\d{2}T') { $o.Time = $part }
            elseif ($part -match '^stage=(.+)$') { $o.Stage = $Matches[1] }
            elseif ($part -match '^code=(-?\d+)$') { $o.Code = [int]$Matches[1] }
            elseif ($part -match '^source=(.+)$') { $o.Source = $Matches[1] }
        }
        return [pscustomobject]$o
    } catch { return $null }
}

$script:KernelApiLoaded = $false
function Get-LoadedKernelModules {
    if (-not $script:KernelApiLoaded) {
        try {
            Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class RotkKernelModules {
    [DllImport("psapi.dll", SetLastError = true)]
    static extern bool EnumDeviceDrivers([Out] IntPtr[] ddAddresses, uint cb, out uint lpcbNeeded);
    [DllImport("psapi.dll", CharSet = CharSet.Unicode)]
    static extern uint GetDeviceDriverBaseNameW(IntPtr ImageBase, StringBuilder lpBaseName, uint nSize);
    [DllImport("psapi.dll", CharSet = CharSet.Unicode)]
    static extern uint GetDeviceDriverFileNameW(IntPtr ImageBase, StringBuilder lpFilename, uint nSize);
    public static string[] List() {
        IntPtr[] buf = new IntPtr[2048];
        uint needed;
        if (!EnumDeviceDrivers(buf, (uint)(buf.Length * IntPtr.Size), out needed)) return null;
        int n = (int)(needed / (uint)IntPtr.Size);
        if (n > buf.Length) { buf = new IntPtr[n]; if (!EnumDeviceDrivers(buf, (uint)(buf.Length * IntPtr.Size), out needed)) return null; }
        List<string> res = new List<string>();
        for (int i = 0; i < n && i < buf.Length; i++) {
            if (buf[i] == IntPtr.Zero) continue;
            StringBuilder b = new StringBuilder(260), f = new StringBuilder(1024);
            GetDeviceDriverBaseNameW(buf[i], b, 260);
            GetDeviceDriverFileNameW(buf[i], f, 1024);
            res.Add(b.ToString() + "|" + f.ToString());
        }
        return res.ToArray();
    }
}
'@
            $script:KernelApiLoaded = $true
        } catch { return $null }
    }
    try { return [RotkKernelModules]::List() } catch { return $null }
}

function Get-WinDivertConsumers([switch]$AllProcesses) {
    $list = New-Object System.Collections.Generic.List[object]
    $procs = if ($AllProcesses) { Get-Process -ErrorAction SilentlyContinue } else {
        Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^(winws|goodbyedpi|zapret|ExitLag.*|byedpi.*|windivert.*)$' }
    }
    foreach ($p in $procs) {
        try {
            $m = $p.Modules | Where-Object { $_.ModuleName -match '^WinDivert' } | Select-Object -First 1
            if ($m) { $list.Add([pscustomobject]@{ Name = $p.ProcessName; Id = $p.Id; Module = $m.FileName }) }
        } catch {}
    }
    return $list
}

function Get-WinDivertState([switch]$Deep) {
    $st = [ordered]@{
        KernelEnum = 'unavailable'; Kernel = @(); Devices = @(); Wmi = @(); DriverQuery = @(); Records = @()
        Events = @(); ScmErrors = @(); Consumers = @(); State = 'UNKNOWN'; LoadedPath = ''; LoadedName = ''
    }

    $mods = Get-LoadedKernelModules
    if ($null -ne $mods -and $mods.Count -gt 0) {
        $st.KernelEnum = 'ok'
        $st.Kernel = @($mods | Where-Object { $_ -match '(?i)divert' } | ForEach-Object {
            $parts = $_.Split('|'); [pscustomobject]@{ Name = $parts[0]; Path = (Format-Path $parts[1]) }
        })
    }

    try { $st.Devices = @([System.ServiceProcess.ServiceController]::GetDevices() | Where-Object { $_.ServiceName -like 'WinDivert*' } | ForEach-Object { [pscustomobject]@{ Name = $_.ServiceName; Status = [string]$_.Status } }) } catch {}
    try { $st.Wmi = @(Get-CimInstance Win32_SystemDriver -ErrorAction Stop | Where-Object { $_.Name -like 'WinDivert*' -or $_.PathName -match '(?i)windivert' } | ForEach-Object { [pscustomobject]@{ Name = $_.Name; State = $_.State; StartMode = $_.StartMode; Path = (Format-Path $_.PathName) } }) } catch {}

    # driverquery output is localized; parse positionally (0 = module name, 5 = state, 13 = path).
    try {
        $csv = & driverquery.exe /v /fo csv 2>$null
        if ($csv) {
            $rows = $csv | Select-Object -Skip 1 | ConvertFrom-Csv -Header (0..14 | ForEach-Object { "c$_" })
            $st.DriverQuery = @($rows | Where-Object { $_.c0 -match '(?i)divert' -or $_.c13 -match '(?i)windivert' } | ForEach-Object { [pscustomobject]@{ Name = $_.c0; State = $_.c5; Path = (Format-Path $_.c13) } })
        }
    } catch {}

    # Service records in the registry (also finds stale, stopped records left by other tools).
    try {
        $st.Records = @(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services' -ErrorAction Stop | ForEach-Object {
            $img = [string]$_.GetValue('ImagePath', '', 'DoNotExpandEnvironmentNames')
            if ($_.PSChildName -like 'WinDivert*' -or $img -match '(?i)windivert') {
                $file = Format-Path $img
                $exists = $false
                try { if ($file) { $exists = Test-Path -LiteralPath ([Environment]::ExpandEnvironmentVariables($file)) } } catch {}
                $isProject = $false
                foreach ($rt in $script:Runtimes) { if ($file -and ($file -ieq (Join-Path $rt.Bin 'WinDivert64.sys'))) { $isProject = $true } }
                [pscustomobject]@{
                    Name = $_.PSChildName; ImagePath = $file; FileExists = $exists; IsProject = $isProject
                    Start = $_.GetValue('Start'); DeleteFlag = $_.GetValue('DeleteFlag')
                }
            }
        })
    } catch {}

    # WinDivert writes its own LOAD/UNLOAD events into the System log.
    try {
        $st.Events = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'WinDivert' } -MaxEvents 6 -ErrorAction Stop | ForEach-Object {
            $msg = ($_.Message -replace '\s+', ' ').Trim()
            $procId = $null; if ($msg -match 'processId=(\d+)') { $procId = [int]$Matches[1] }
            [pscustomobject]@{ Time = $_.TimeCreated; Kind = $(if ($msg -match 'UNLOAD') { 'UNLOAD' } elseif ($msg -match 'LOAD') { 'LOAD' } else { $msg }); Pid = $procId; Text = $msg }
        })
    } catch {}

    # Service Control Manager start failures for WinDivert services in the last 14 days.
    try {
        $st.ScmErrors = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Service Control Manager'; Id = 7000; StartTime = (Get-Date).AddDays(-14) } -MaxEvents 200 -ErrorAction Stop |
            Where-Object { $_.Properties.Count -ge 2 -and [string]$_.Properties[0].Value -match '(?i)windivert' } |
            Select-Object -First 5 | ForEach-Object {
                $raw = [string]$_.Properties[1].Value
                $code = $null
                if ($raw -match '%%(\d+)') { $code = [int]$Matches[1] }
                else {
                    foreach ($c in $ErrorKB.Keys) {
                        try { if ($raw.Trim() -eq (New-Object System.ComponentModel.Win32Exception([int]$c)).Message.Trim()) { $code = [int]$c } } catch {}
                    }
                }
                [pscustomobject]@{ Time = $_.TimeCreated; Service = [string]$_.Properties[0].Value; Code = $code; Text = $raw }
            })
    } catch {}

    # A start failure followed by a successful LOAD is already resolved; keep only unresolved ones.
    $lastLoad = $st.Events | Where-Object { $_.Kind -eq 'LOAD' } | Select-Object -First 1
    if ($lastLoad) { $st.ScmErrors = @($st.ScmErrors | Where-Object { $_.Time -gt $lastLoad.Time }) }

    $st.Consumers = @(Get-WinDivertConsumers -AllProcesses:$Deep)

    # Derive the overall driver state from all sources.
    $loadedSignals = @()
    if ($st.Kernel.Count -gt 0) { $loadedSignals += 'kernel' ; $st.LoadedPath = $st.Kernel[0].Path; $st.LoadedName = $st.Kernel[0].Name }
    $runDev = @($st.Devices | Where-Object { $_.Status -eq 'Running' })
    if ($runDev.Count -gt 0) { $loadedSignals += 'scm'; if (-not $st.LoadedName) { $st.LoadedName = $runDev[0].Name } }
    $runWmi = @($st.Wmi | Where-Object { $_.State -eq 'Running' })
    if ($runWmi.Count -gt 0) { $loadedSignals += 'wmi'; if (-not $st.LoadedPath) { $st.LoadedPath = $runWmi[0].Path }; $st.LoadedName = $runWmi[0].Name }

    if ($loadedSignals.Count -gt 0) { $st.State = 'LOADED' }
    elseif ($st.KernelEnum -eq 'ok') { $st.State = 'NOT LOADED' }
    else { $st.State = 'UNKNOWN' }
    $st.Signals = ($loadedSignals -join '+')
    return [pscustomobject]$st
}

function Get-FileReport($rt) {
    $rep = New-Object System.Collections.Generic.List[object]
    foreach ($f in $RuntimeFiles) {
        $p = Join-Path $rt.Bin $f
        $o = [ordered]@{ File = $f; Exists = (Test-Path -LiteralPath $p); Hash = ''; Match = $false }
        if ($o.Exists) {
            try { $o.Hash = (Get-FileHash -LiteralPath $p -Algorithm SHA256 -ErrorAction Stop).Hash; $o.Match = ($o.Hash -eq $ExpectedHashes[$f]) } catch {}
        }
        $rep.Add([pscustomobject]$o)
    }
    foreach ($f in @($rt.Filter, $rt.Conf)) {
        $rep.Add([pscustomobject]@{ File = (Split-Path $f -Leaf); Exists = (Test-Path -LiteralPath $f); Hash = ''; Match = $true })
    }
    return $rep
}

function Get-DriverSignature($rt) {
    $p = Join-Path $rt.Bin 'WinDivert64.sys'
    if (-not (Test-Path -LiteralPath $p)) { return [pscustomobject]@{ Status = 'MISSING'; Signer = '' } }
    try {
        $sig = Get-AuthenticodeSignature -LiteralPath $p -ErrorAction Stop
        $signer = ''
        if ($sig.SignerCertificate) { $signer = ($sig.SignerCertificate.Subject -split ',')[0] -replace '^CN=', '' }
        return [pscustomobject]@{ Status = [string]$sig.Status; Signer = $signer }
    } catch { return [pscustomobject]@{ Status = 'UNKNOWN'; Signer = '' } }
}

function Get-BfeState {
    try {
        $s = Get-Service -Name BFE -ErrorAction Stop
        return [pscustomobject]@{ Status = [string]$s.Status; StartType = [string]$s.StartType }
    } catch { return [pscustomobject]@{ Status = 'MISSING'; StartType = '' } }
}

function Get-SmartAppControl {
    try {
        $v = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -ErrorAction Stop).VerifiedAndReputablePolicyState
        switch ($v) { 0 { return 'OFF' } 1 { return 'ON' } 2 { return 'EVALUATION' } default { return 'UNKNOWN' } }
    } catch { return 'NOT PRESENT' }
}

function Get-MemoryIntegrity {
    try {
        $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction Stop
        if ($dg.SecurityServicesRunning -contains 2) { return 'ON' } else { return 'OFF' }
    } catch { return 'UNKNOWN' }
}

function Get-CodeIntegrityEvents {
    $ids = @(3001, 3002, 3003, 3004, 3010, 3023, 3033, 3034, 3036, 3063, 3064, 3076, 3077)
    try {
        return @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-CodeIntegrity/Operational'; Id = $ids; StartTime = (Get-Date).AddDays(-30) } -MaxEvents 3000 -ErrorAction Stop |
            Where-Object { (($_.Properties | ForEach-Object { [string]$_.Value }) -join ' ') -match '(?i)windivert|winws|cygwin1' } |
            Select-Object -First 5 | ForEach-Object { [pscustomobject]@{ Time = $_.TimeCreated; Id = $_.Id; Text = (($_.Message -split "`n")[0]).Trim() } })
    } catch { return @() }
}

function Get-DefenderHits {
    $res = [ordered]@{ Available = $false; Hits = @() }
    try {
        $det = @(Get-MpThreatDetection -ErrorAction Stop)
        $res.Available = $true
        $threats = @{}
        try { Get-MpThreat -ErrorAction Stop | ForEach-Object { $threats[[string]$_.ThreatID] = $_.ThreatName } } catch {}
        $res.Hits = @($det | Where-Object { (($_.Resources) -join ';') -match '(?i)windivert|winws|cygwin1|H1Z1-ROTK|stun\.bin' } |
            Select-Object -First 5 | ForEach-Object {
                [pscustomobject]@{
                    Time = $_.InitialDetectionTime; Threat = $threats[[string]$_.ThreatID]
                    Action = [string]$_.ThreatStatusID; Resource = ((($_.Resources) | Select-Object -First 1) -replace '^file:_', '')
                }
            })
    } catch {}
    return [pscustomobject]$res
}

function Get-ConflictInventory {
    $patterns = [ordered]@{
        'GoodbyeDPI'          = '^goodbyedpi$'
        'ExitLag (app)'       = '^ExitLag$'
        'ExitLag (service)'   = '^ExitLagPmService$'
        'v2rayN'              = '^v2rayN$'
        'Xray / V2Ray core'   = '^(xray|v2ray|wv2ray)$'
        'sing-box'            = '^sing-box$'
        'Clash / Mihomo'      = '^(clash.*|mihomo.*|verge-mihomo)$'
        'Hiddify'             = '^(Hiddify.*|HiddifyCli)$'
        'NekoRay / NekoBox'   = '^(nekoray|nekobox.*)$'
        'WireGuard'           = '^(wireguard|wg)$'
        'AmneziaVPN / AWG'    = '^(AmneziaVPN.*|amneziawg.*|AmneziaWG)$'
        'OpenVPN'             = '^(openvpn|openvpn-gui|openvpnserv.*)$'
        'Outline'             = '^(Outline.*|outline_proxy_controller)$'
        'Zapret helper'       = '^(zapret.*|byedpi.*|ciadpi)$'
    }
    $found = New-Object System.Collections.Generic.List[object]
    $procs = @(Get-Process -ErrorAction SilentlyContinue)
    foreach ($k in $patterns.Keys) {
        $hit = @($procs | Where-Object { $_.ProcessName -match $patterns[$k] })
        if ($hit.Count -gt 0) { $found.Add([pscustomobject]@{ Name = $k; Pids = (($hit | ForEach-Object { $_.Id }) -join ',') }) }
    }
    return $found
}

function Get-NetworkModel {
    $m = [ordered]@{ Adapters = @(); IfMetric = @{}; Defaults = @(); Persistent = @(); Gateways = @{}; IfAddr = @{}; VirtualIdx = @{} }
    try {
        $m.Adapters = @(Get-NetAdapter -ErrorAction Stop | Select-Object Name, InterfaceDescription, Status, LinkSpeed, ifIndex, Virtual, HardwareInterface)
        foreach ($a in $m.Adapters) {
            $virt = ($a.Virtual -or (-not $a.HardwareInterface) -or $a.InterfaceDescription -match '(?i)wintun|wireguard|tap-windows|tap adapter|openvpn|tun|hyper-v|vmware|virtualbox|exitlag|zerotier|tailscale|hamachi|radmin')
            $m.VirtualIdx[[int]$a.ifIndex] = [bool]$virt
        }
    } catch {}
    try { Get-NetIPInterface -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object { $m.IfMetric[[int]$_.ifIndex] = $_ } } catch {}
    try { $m.Defaults = @(Get-NetRoute -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.DestinationPrefix -in @('0.0.0.0/0', '0.0.0.0/1', '128.0.0.0/1') }) } catch {}
    try { $m.Persistent = @(Get-NetRoute -PolicyStore PersistentStore -AddressFamily IPv4 -ErrorAction Stop) } catch {}
    try {
        Get-NetIPConfiguration -ErrorAction Stop | ForEach-Object {
            if ($_.IPv4DefaultGateway) { $m.Gateways[[int]$_.InterfaceIndex] = @($_.IPv4DefaultGateway | ForEach-Object { $_.NextHop }) }
        }
    } catch {}
    try { Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object { $m.IfAddr[$_.IPAddress] = [pscustomobject]@{ Index = [int]$_.ifIndex; Prefix = $_.PrefixLength; Alias = $_.InterfaceAlias } } } catch {}
    return [pscustomobject]$m
}

function Get-AdapterInfo($net, [int]$idx) {
    $a = $net.Adapters | Where-Object { [int]$_.ifIndex -eq $idx } | Select-Object -First 1
    $alias = if ($a) { $a.Name } else { "ifIndex $idx" }
    $desc = if ($a) { $a.InterfaceDescription } else { '' }
    $virt = $false; if ($net.VirtualIdx.ContainsKey($idx)) { $virt = $net.VirtualIdx[$idx] }
    $mtu = ''; $metric = ''
    if ($net.IfMetric.ContainsKey($idx)) { $mtu = $net.IfMetric[$idx].NlMtu; $metric = $net.IfMetric[$idx].InterfaceMetric }
    return [pscustomobject]@{ Alias = $alias; Description = $desc; Virtual = $virt; Mtu = $mtu; Metric = $metric; Status = $(if ($a) { [string]$a.Status } else { '' }) }
}

function Resolve-RouteTo($net, [string]$ip) {
    try {
        $r = @(Find-NetRoute -RemoteIPAddress $ip -ErrorAction Stop)
        $route = $r | Where-Object { $_.DestinationPrefix } | Select-Object -First 1
        $addr = $r | Where-Object { $_.IPAddress } | Select-Object -First 1
        if (-not $route) { return $null }
        $idx = [int]$route.ifIndex
        $persist = @($net.Persistent | Where-Object { $_.DestinationPrefix -eq $route.DestinationPrefix -and [int]$_.ifIndex -eq $idx })
        return [pscustomobject]@{
            Ip = $ip; Index = $idx; Prefix = $route.DestinationPrefix; NextHop = $route.NextHop; RouteMetric = $route.RouteMetric
            Source = $(if ($addr) { $addr.IPAddress } else { '' }); Persistent = ($persist.Count -gt 0); Adapter = (Get-AdapterInfo $net $idx)
        }
    } catch { return $null }
}

function Test-InSubnet([string]$ip, [string]$net, [int]$prefix) {
    try {
        $mask = if ($prefix -eq 0) { [uint32]0 } else { [uint32]([math]::Pow(2, 32) - [math]::Pow(2, 32 - $prefix)) }
        return (((ConvertTo-UInt32IP $ip) -band $mask) -eq ((ConvertTo-UInt32IP $net) -band $mask))
    } catch { return $false }
}

function Measure-Icmp([string]$ip, [int]$Count = 10, [int]$TimeoutMs = 1000, [int]$GapMs = 150) {
    $ping = New-Object System.Net.NetworkInformation.Ping
    $rtts = New-Object System.Collections.Generic.List[double]
    $sent = 0
    for ($i = 0; $i -lt $Count; $i++) {
        $sent++
        try { $r = $ping.Send($ip, $TimeoutMs); if ($r.Status -eq 'Success') { $rtts.Add([double]$r.RoundtripTime) } } catch {}
        if ($GapMs -gt 0) { Start-Sleep -Milliseconds $GapMs }
    }
    $ping.Dispose()
    if ($rtts.Count -eq 0) { return [pscustomobject]@{ Ip = $ip; Sent = $sent; Received = 0; Loss = 100; Min = $null; Avg = $null; Max = $null } }
    $m = $rtts | Measure-Object -Minimum -Maximum -Average
    return [pscustomobject]@{ Ip = $ip; Sent = $sent; Received = $rtts.Count; Loss = [math]::Round(100 * ($sent - $rtts.Count) / $sent); Min = [math]::Max(1, $m.Minimum); Avg = [math]::Max(1, [math]::Round($m.Average)); Max = [math]::Max(1, $m.Maximum) }
}

# Parallel TTL-limited ICMP probes: a 2-3 second traceroute that needs no tracert parsing.
function Trace-Hops([string]$ip, [int]$MaxHops = 30, [int]$TimeoutMs = 1500, [int]$Rounds = 2) {
    $best = @{}
    $buf = New-Object byte[] 32
    for ($round = 0; $round -lt $Rounds; $round++) {
        $tasks = @{}; $start = @{}
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $pings = New-Object System.Collections.Generic.List[object]
        for ($ttl = 1; $ttl -le $MaxHops; $ttl++) {
            $p = New-Object System.Net.NetworkInformation.Ping
            $pings.Add($p)
            $opt = New-Object System.Net.NetworkInformation.PingOptions($ttl, $true)
            $start[$ttl] = $sw.Elapsed.TotalMilliseconds
            try { $tasks[$ttl] = $p.SendPingAsync($ip, $TimeoutMs, $buf, $opt) } catch {}
        }
        $pending = New-Object System.Collections.Generic.List[int]
        foreach ($k in $tasks.Keys) { $pending.Add([int]$k) }
        $deadline = $TimeoutMs + 1000
        while ($pending.Count -gt 0 -and $sw.ElapsedMilliseconds -lt $deadline) {
            $arr = [System.Threading.Tasks.Task[]]@($pending | ForEach-Object { $tasks[$_] })
            [void][System.Threading.Tasks.Task]::WaitAny($arr, 100)
            $now = $sw.Elapsed.TotalMilliseconds
            foreach ($k in @($pending)) {
                $t = $tasks[$k]
                if ($t.IsCompleted) {
                    [void]$pending.Remove($k)
                    if ($t.Status -eq 'RanToCompletion' -and $t.Result.Address -and $t.Result.Status -in @('TtlExpired', 'Success')) {
                        $ms = [math]::Round($now - $start[$k])
                        $hop = [pscustomobject]@{ Ttl = $k; Address = $t.Result.Address.ToString(); Ms = $ms; Final = ($t.Result.Status -eq 'Success') }
                        if (-not $best.ContainsKey($k) -or $best[$k].Ms -gt $ms) { $best[$k] = $hop }
                    }
                }
            }
        }
        foreach ($p in $pings) { try { $p.Dispose() } catch {} }
    }
    $hops = @($best.Values | Sort-Object Ttl)
    $final = $hops | Where-Object { $_.Final } | Sort-Object Ttl | Select-Object -First 1
    if ($final) { $hops = @($hops | Where-Object { $_.Ttl -le $final.Ttl }) }
    return [pscustomobject]@{ Hops = $hops; Reached = [bool]$final; HopCount = $(if ($final) { $final.Ttl } else { $null }) }
}

function Read-FilterModel([string]$path) {
    $m = [ordered]@{ Text = ''; Ranges = @(); Ports = @(); Parsed = $false }
    if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]$m }
    $t = (Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue)
    if (-not $t) { return [pscustomobject]$m }
    $m.Text = $t.Trim()
    $ip = '(\d{1,3}(?:\.\d{1,3}){3})'
    foreach ($x in [regex]::Matches($t, "ip\.DstAddr\s*>=\s*$ip\s*and\s*ip\.DstAddr\s*<=\s*$ip")) { $m.Ranges += , @($x.Groups[1].Value, $x.Groups[2].Value) }
    foreach ($x in [regex]::Matches($t, "ip\.DstAddr\s*==\s*$ip")) { $m.Ranges += , @($x.Groups[1].Value, $x.Groups[1].Value) }
    foreach ($x in [regex]::Matches($t, 'udp\.DstPort\s*>=\s*(\d+)\s*and\s*udp\.DstPort\s*<=\s*(\d+)')) { $m.Ports += , @([int]$x.Groups[1].Value, [int]$x.Groups[2].Value) }
    foreach ($x in [regex]::Matches($t, 'udp\.DstPort\s*==\s*(\d+)')) { $m.Ports += , @([int]$x.Groups[1].Value, [int]$x.Groups[1].Value) }
    $m.Parsed = ($m.Ranges.Count -gt 0)
    return [pscustomobject]$m
}

function Test-FilterCovers($filter, [string]$ip, [int]$port) {
    if (-not $filter.Parsed) { return $null }
    $ipOk = $false
    foreach ($r in $filter.Ranges) { if (Test-IPInRange $ip $r[0] $r[1]) { $ipOk = $true } }
    if (-not $ipOk) { return $false }
    if ($filter.Ports.Count -eq 0) { return $true }
    foreach ($p in $filter.Ports) { if ($port -ge $p[0] -and $port -le $p[1]) { return $true } }
    return $false
}

# Game-reported data-center latency from the ROTK Launcher session logs (numbers only).
function Get-GameReportedLatency {
    $dir = Join-Path $env:APPDATA 'ROTK Launcher\diagnostics'
    if (-not (Test-Path $dir)) { return @() }
    $sessions = @(Get-ChildItem $dir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $f = Join-Path $_.FullName 'events.jsonl'
        if (Test-Path $f) { Get-Item $f }
    } | Sort-Object LastWriteTime -Descending | Select-Object -First 6)
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($f in $sessions) {
        try {
            $txt = [System.IO.File]::ReadAllText($f.FullName)
            $start = ''
            if ($txt -match '"at":"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}):') { $start = $Matches[1] }
            $vals = New-Object System.Collections.Generic.List[int]
            $dc = ''
            foreach ($x in [regex]::Matches($txt, 'Id=\d+\((\w+)\) Available=\d Selected=1[^\\"]*?Ping=(\d+)')) {
                $v = [int]$x.Groups[2].Value
                if ($v -lt 100000) { $vals.Add($v); $dc = $x.Groups[1].Value }
            }
            if ($vals.Count -gt 0) {
                $sorted = $vals | Sort-Object
                $out.Add([pscustomobject]@{ Start = $start; DataCenter = $dc; Samples = $vals.Count; Min = $sorted[0]; Median = $sorted[[int][math]::Floor(($sorted.Count - 1) / 2)]; Max = $sorted[-1] })
            }
        } catch {}
    }
    return $out
}

# Short NIC-level capture to discover the real UDP endpoints used by H1Z1.exe.
function Invoke-GameCapture([int[]]$GamePids, [int]$Seconds, $net) {
    $res = [ordered]@{ Status = 'skipped'; Reason = ''; Flows = @(); TunHits = 0 }
    $pktmon = Join-Path $env:SystemRoot 'System32\pktmon.exe'
    if (-not (Test-Path $pktmon)) { $res.Reason = 'pktmon is not available on this Windows build'; return [pscustomobject]$res }

    $ports = New-Object 'System.Collections.Generic.HashSet[int]'
    $collectPorts = { foreach ($gp in $GamePids) { try { Get-NetUDPEndpoint -OwningProcess $gp -ErrorAction Stop | ForEach-Object { [void]$ports.Add([int]$_.LocalPort) } } catch {} } }
    & $collectPorts

    $base = Join-Path $env:TEMP ("rotk-diag-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $etl = "$base.etl"; $txt = "$base.txt"
    $o = & $pktmon start --capture --comp nics --pkt-size 160 --file-name $etl 2>&1
    if ($LASTEXITCODE -ne 0) {
        $res.Status = 'unavailable'; $res.Reason = 'pktmon could not start (another capture may be running or this Windows build is too old)'
        return [pscustomobject]$res
    }
    try {
        $deadline = (Get-Date).AddSeconds($Seconds)
        while ((Get-Date) -lt $deadline) { Start-Sleep -Seconds 1; & $collectPorts }
    } finally {
        & $pktmon stop 2>&1 | Out-Null
    }
    & $pktmon etl2txt $etl -o $txt 2>&1 | Out-Null
    if (-not (Test-Path $txt)) { & $pktmon format $etl -o $txt 2>&1 | Out-Null }
    if (-not (Test-Path $txt)) {
        Remove-Item $etl -Force -ErrorAction SilentlyContinue
        $res.Status = 'unavailable'; $res.Reason = 'pktmon capture could not be converted'
        return [pscustomobject]$res
    }

    $bytes = [System.IO.File]::ReadAllBytes($txt)
    $isUtf16 = ($bytes.Length -gt 3 -and (($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or $bytes[1] -eq 0 -or $bytes[3] -eq 0))
    $content = if ($isUtf16) { [System.Text.Encoding]::Unicode.GetString($bytes) } else { [System.Text.Encoding]::UTF8.GetString($bytes) }
    Remove-Item $etl, $txt -Force -ErrorAction SilentlyContinue

    $localAddrs = @{}
    foreach ($k in $net.IfAddr.Keys) { $localAddrs[$k] = $net.IfAddr[$k] }
    $flows = @{}
    $ts = $null
    $rxTs = '(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.(\d{1,9})'
    $rxPkt = '(\d{1,3}(?:\.\d{1,3}){3})\.(\d+) > (\d{1,3}(?:\.\d{1,3}){3})\.(\d+): '
    foreach ($line in ($content -split "`r?`n")) {
        $mt = [regex]::Match($line, $rxTs)
        if ($mt.Success) {
            $frac = $mt.Groups[2].Value.PadRight(7, '0').Substring(0, 7)
            $ts = [datetime]::ParseExact($mt.Groups[1].Value + '.' + $frac, 'yyyy-MM-dd HH:mm:ss.fffffff', [Globalization.CultureInfo]::InvariantCulture)
            continue
        }
        $mp = [regex]::Match($line, $rxPkt)
        if (-not $mp.Success -or $line -match 'Flags \[' -or $line -match 'ICMP') { continue }
        $src = $mp.Groups[1].Value; $sp = [int]$mp.Groups[2].Value; $dst = $mp.Groups[3].Value; $dp = [int]$mp.Groups[4].Value
        if ($localAddrs.ContainsKey($src) -and $ports.Contains($sp)) { $dir = 'tx'; $lip = $src; $rip = $dst; $rport = $dp }
        elseif ($localAddrs.ContainsKey($dst) -and $ports.Contains($dp)) { $dir = 'rx'; $lip = $dst; $rip = $src; $rport = $sp }
        else { continue }
        $key = "${rip}:$rport"
        if (-not $flows.ContainsKey($key)) {
            $flows[$key] = [pscustomobject]@{ Ip = $rip; Port = $rport; Tx = 0; Rx = 0; Ifaces = (New-Object 'System.Collections.Generic.HashSet[string]'); Events = (New-Object System.Collections.Generic.List[object]) }
        }
        $fl = $flows[$key]
        if ($dir -eq 'tx') { $fl.Tx++ } else { $fl.Rx++ }
        [void]$fl.Ifaces.Add($localAddrs[$lip].Alias)
        if ($ts -and $fl.Events.Count -lt 5000) { $fl.Events.Add([pscustomobject]@{ T = $ts; D = $dir }) }
        if ($net.VirtualIdx.ContainsKey($localAddrs[$lip].Index) -and $net.VirtualIdx[$localAddrs[$lip].Index]) { $res.TunHits++ }
    }

    $list = New-Object System.Collections.Generic.List[object]
    foreach ($fl in $flows.Values) {
        # Request->reply pairing is only meaningful for low-rate, balanced ping-style flows
        # (a session flow where the server pushes most packets would pair unrelated packets).
        $rtt = $null
        $pps = ($fl.Tx + $fl.Rx) / [math]::Max(1, $Seconds)
        $balanced = ([math]::Min($fl.Tx, $fl.Rx) / [math]::Max(1, [math]::Max($fl.Tx, $fl.Rx))) -ge 0.5
        if ($fl.Tx -ge 3 -and $fl.Rx -ge 3 -and $pps -le 20 -and $balanced) {
            $samples = New-Object System.Collections.Generic.List[double]
            $pendingTx = $null
            foreach ($e in ($fl.Events | Sort-Object T)) {
                if ($e.D -eq 'tx') { if (-not $pendingTx) { $pendingTx = $e.T } }
                elseif ($pendingTx) { $samples.Add(($e.T - $pendingTx).TotalMilliseconds); $pendingTx = $null }
            }
            if ($samples.Count -ge 3) { $s = $samples | Sort-Object; $rtt = [math]::Round($s[[int][math]::Floor(($s.Count - 1) / 2)]) }
        }
        $viaVirtual = $false
        foreach ($alias in $fl.Ifaces) {
            $ad = $net.Adapters | Where-Object { $_.Name -eq $alias } | Select-Object -First 1
            if ($ad -and $net.VirtualIdx.ContainsKey([int]$ad.ifIndex) -and $net.VirtualIdx[[int]$ad.ifIndex]) { $viaVirtual = $true }
        }
        $list.Add([pscustomobject]@{ Ip = $fl.Ip; Port = $fl.Port; Tx = $fl.Tx; Rx = $fl.Rx; Ifaces = (@($fl.Ifaces) -join ','); Pps = [math]::Round($pps, 1); PassiveRtt = $rtt; Virtual = $viaVirtual })
        [void]$script:AllowedIPs.Add($fl.Ip)
    }
    $res.Flows = @($list | Sort-Object { $_.Tx + $_.Rx } -Descending)
    $res.Status = 'ok'
    $res.Ports = @($ports)
    return [pscustomobject]$res
}

# --------------------------------------------------------------------------------------------
# Shared evaluation blocks
# --------------------------------------------------------------------------------------------
function Show-DriverBlock($rt, $drv, $bfe, $sig, $files, $projWinws, [switch]$Compact) {
    $missing = @($files | Where-Object { -not $_.Exists } | ForEach-Object { $_.File })
    $bad = @($files | Where-Object { $_.Exists -and $_.Hash -and -not $_.Match } | ForEach-Object { $_.File })
    if ($missing.Count -gt 0) { Out-KV 'Files' ('MISSING: ' + ($missing -join ', ')) 'Red' 4 }
    elseif ($bad.Count -gt 0) { Out-KV 'Files' ('PRESENT, MODIFIED: ' + ($bad -join ', ')) 'Yellow' 4 }
    else { Out-KV 'Files' 'OK' 'Green' 4 }

    $sigColor = if ($sig.Status -eq 'Valid') { 'Green' } else { 'Red' }
    $sigText = if ($sig.Status -eq 'Valid') { "VALID [$($sig.Signer)]" } else { $sig.Status.ToUpper() }
    Out-KV 'Signature' $sigText $sigColor 4

    $bfeColor = if ($bfe.Status -eq 'Running') { 'Green' } else { 'Red' }
    Out-KV 'BFE' ("$($bfe.Status.ToUpper()) [$($bfe.StartType)]") $bfeColor 4

    switch ($drv.State) {
        'LOADED' {
            $name = if ($drv.LoadedName) { $drv.LoadedName } else { 'WinDivert' }
            $where = if ($drv.LoadedPath) { ", $($drv.LoadedPath)" } else { '' }
            Out-KV 'Driver' "LOADED [$name$where]" 'Green' 4
        }
        'NOT LOADED' { Out-KV 'Driver' 'NOT LOADED' $(if ($projWinws) { 'Red' } else { 'Gray' }) 4 }
        default {
            Out-KV 'Driver' 'UNKNOWN' 'Yellow' 4
            $why = if (-not $script:IsAdmin) { 'not running as administrator, kernel driver list is not readable' } else { 'Windows driver state could not be resolved from any source' }
            Out-KV 'Reason' $why 'Yellow' 4
        }
    }

    $users = New-Object System.Collections.Generic.List[string]
    foreach ($c in $drv.Consumers) {
        $tag = if ($projWinws -and $c.Id -eq $projWinws.Id) { "project winws PID $($c.Id)" } else { "$($c.Name) PID $($c.Id)" }
        $users.Add($tag)
    }
    if ($users.Count -gt 0) { Out-KV 'Used by' ($users -join '; ') 'Gray' 4 }
    elseif ($projWinws -and $drv.State -eq 'LOADED') { Out-KV 'Used by' "project winws PID $($projWinws.Id)" 'Gray' 4 }
    elseif ($drv.State -eq 'LOADED') { Out-KV 'Used by' 'no WinDivert consumer process found (driver idle)' 'Gray' 4 }

    if ($drv.State -eq 'LOADED' -and $drv.LoadedPath) {
        $isProj = $false
        foreach ($r in $script:Runtimes) { if ($drv.LoadedPath -ieq (Join-Path $r.Bin 'WinDivert64.sys')) { $isProj = $true } }
        if (-not $isProj) { Out-KV 'Loaded from' 'another folder (driver instance shared with another tool or older copy)' 'Yellow' 4 }
    }

    $stale = @(Get-StaleRecords $drv)
    foreach ($s in $stale) { Out-KV 'Stale service' ("$($s.Name) -> $($s.ImagePath) [file missing, folder '$(Get-ParentLeaf $s.ImagePath)']") 'Red' 4 }

    if (-not $Compact) {
        $last = $drv.Events | Select-Object -First 1
        if ($last) { Out-KV 'Last driver event' ('{0:yyyy-MM-dd HH:mm:ss} {1} (pid {2})' -f $last.Time, $last.Kind, $last.Pid) 'Gray' 4 }
        foreach ($e in $drv.ScmErrors) {
            $c = if ($null -ne $e.Code) { Get-ErrorText $e.Code } else { $e.Text }
            Out-KV 'Start failure' ('{0:yyyy-MM-dd HH:mm} {1}: {2}' -f $e.Time, $e.Service, $c) 'Red' 4
        }
    }
}

function Get-FlowClass($filter, $f) {
    # in-filter   : covered by filter.txt (ROTK login / ping / match traffic we protect)
    # region-ping : UDP 20140-20141 data-center ping to another region's host (the game pings
    #               every region in the lobby; that is not gameplay traffic)
    # outside     : ROTK-like game traffic NOT covered by filter.txt
    $cov = Test-FilterCovers $filter $f.Ip $f.Port
    if ($cov) { return 'in-filter' }
    if ($f.Port -in @(20140, 20141)) { return 'region-ping' }
    if (($f.Port -ge 20000 -and $f.Port -le 23000) -or (Test-IPInRange $f.Ip $RotkSupernet[0] $RotkSupernet[1])) { return 'outside' }
    return 'other'
}

function Get-StaleRecords($drv) {
    # A WinDivert service record whose driver file no longer exists breaks every WinDivert tool
    # (WinDivertOpen reuses the record and fails with error 2/3). Not stale while a driver is loaded.
    if ($drv.State -eq 'LOADED') { return @() }
    return @($drv.Records | Where-Object { -not $_.FileExists })
}

function Get-ParentLeaf([string]$p) {
    try { return (Split-Path (Split-Path $p -Parent) -Leaf) } catch { return '' }
}

function Get-StaleAction($s) {
    return ('Remove the leftover service record (WinDivert recreates it automatically): open Command Prompt as administrator and run:  sc delete ' + $s.Name)
}

function Get-ProjectWinws {
    $inv = Get-WinwsInventory
    $proj = $null; $projRt = $null
    foreach ($rt in $script:Runtimes) {
        $tp = Get-TrackedPid $rt '.winws.pid'
        $match = $inv | Where-Object { $_.Owner -eq $rt.Label -and ($null -eq $tp -or $_.Id -eq $tp) } | Select-Object -First 1
        if ($match -and -not $proj) { $proj = $match; $projRt = $rt }
    }
    $others = @($inv | Where-Object { -not $proj -or $_.Id -ne $proj.Id })
    return [pscustomobject]@{ Project = $proj; Runtime = $projRt; Others = $others; All = $inv }
}

function Get-PrimaryRuntime {
    $inst = $script:Runtimes | Where-Object { $_.Label -eq 'auto-mode' } | Select-Object -First 1
    $loc = $script:Runtimes | Where-Object { $_.Label -ne 'auto-mode' } | Select-Object -First 1
    if ($loc) { return $loc }
    return $inst
}

function Get-AutoModeState {
    $o = [ordered]@{ Installed = $false; State = ''; NoTimeLimit = $null; Battery = $null; WatcherPid = $null; Version = '' }
    try {
        $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        $o.Installed = $true; $o.State = [string]$t.State
        $lim = [string]$t.Settings.ExecutionTimeLimit
        $o.NoTimeLimit = ($lim -eq 'PT0S' -or [string]::IsNullOrEmpty($lim))
        $o.Battery = (-not $t.Settings.DisallowStartIfOnBatteries -and -not $t.Settings.StopIfGoingOnBatteries)
    } catch {
        & schtasks.exe /query /tn $TaskName > $null 2>&1
        if ($LASTEXITCODE -eq 0) { $o.Installed = $true; $o.State = 'registered' }
    }
    $inst = $script:Runtimes | Where-Object { $_.Label -eq 'auto-mode' } | Select-Object -First 1
    if ($inst) {
        $wp = Get-TrackedPid $inst '.watcher.pid'
        if ($wp) { $p = Get-Process -Id $wp -ErrorAction SilentlyContinue; if ($p -and $p.ProcessName -match 'powershell|pwsh') { $o.WatcherPid = $wp } }
        $vf = Join-Path $inst.Bin 'VERSION.txt'
        $o.Version = if (Test-Path $vf) { (Get-Content $vf -ErrorAction SilentlyContinue | Select-Object -First 1).Trim() } else { 'v1.2.x or older (no VERSION.txt)' }
    }
    return [pscustomobject]$o
}

function Show-LastStart($rt) {
    $ls = Get-LastStartRecord $rt
    if (-not $ls) { return $null }
    $what = if ($ls.Stage -eq 'launch') { 'winws.exe could not be launched' } else { 'winws.exe exited during startup' }
    Out-KV 'Last start' ("FAILED $($ls.Time) [$($ls.Source)] - $what") 'Red' 4
    if ($ls.Code -ge 0) { Out-KV 'Windows error' (Get-ErrorText $ls.Code) 'Red' 4 }
    return $ls
}

# --------------------------------------------------------------------------------------------
# MODE: SanitizerTest
# --------------------------------------------------------------------------------------------
if ($Mode -eq 'SanitizerTest') {
    $planted = @(
        "user=$env:USERNAME host=$env:COMPUTERNAME",
        "path $env:USERPROFILE\Downloads\H1Z1-ROTK-Russia\_runtime\winws.exe",
        'path D:\Games\Some Folder\zapret\WinDivert64.sys',
        '\??\E:\tools\zapret-old\WinDivert64.sys',
        'vless://0b6d2f5e-1c2a-4f0e-9a3b-7c8d9e0f1a2b@203.0.113.10:443?security=reality&pbk=Zx9KpQwErTyUiOp1234567890abcdefGHIJKLmnopQR&sid=6ba85179e30d4fc2#name',
        'subscription https://sub.example.org/api/v1/client/subscribe?token=abcdef1234567890abcdef1234567890',
        'public 198.51.100.23 traceroute hop 212.188.6.45 ok 162.19.94.95 lan 192.168.1.1',
        'v6 2a00:1370:81a8:2912:96f3:73e7:e0fc:9cae fe80::1 time 14:56:02',
        'steam 76561198000000000 sid S-1-5-21-1111111111-2222222222-3333333333-1001',
        'mail someone@example.com uuid 123e4567-e89b-12d3-a456-426614174000',
        'cookie: sessionid=QWERTYUIOPASDFGHJKLZXCVBNM1234567890qwerty',
        ('hash ' + $ExpectedHashes['winws.exe'])
    )
    $leaks = New-Object System.Collections.Generic.List[string]
    $outText = (($planted | ForEach-Object { Protect-Text $_ }) -join "`n")
    $mustNot = @($env:USERNAME, $env:COMPUTERNAME, 'Downloads\H1Z1', 'D:\Games', 'E:\tools', 'vless://', '0b6d2f5e', 'Zx9KpQwErTy', 'sub.example.org', 'abcdef1234567890',
                 '198.51.100.23', '212.188.6.45', '2a00:1370', '76561198000000000', 'S-1-5-21-1111', 'someone@example.com', '123e4567', 'QWERTYUIOP', '203.0.113.10')
    foreach ($m in $mustNot) { if ($m -and $outText.IndexOf($m, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $leaks.Add($m) } }
    $mustKeep = @('162.19.94.95', '192.168.1.1', '14:56:02', $ExpectedHashes['winws.exe'], 'WinDivert64.sys')
    foreach ($m in $mustKeep) { if ($outText.IndexOf($m, [StringComparison]::OrdinalIgnoreCase) -lt 0) { $leaks.Add("LOST:$m") } }
    Write-Output $outText
    if ($leaks.Count -gt 0) { Write-Output ('SANITIZER-FAIL: ' + ($leaks -join ' | ')); exit 1 }
    Write-Output 'SANITIZER-OK'
    exit 0
}

# --------------------------------------------------------------------------------------------
# MODE: Startup - called right after winws.exe failed to start
# --------------------------------------------------------------------------------------------
if ($Mode -eq 'Startup') {
    $rt = Get-PrimaryRuntime
    $files = Get-FileReport $rt
    $sig = Get-DriverSignature $rt
    $bfe = Get-BfeState
    $drv = Get-WinDivertState
    Out-Line ''
    if ($StartupStage -eq 'launch') { Out-Line ' [ERROR] winws.exe could not be launched.' 'Red' }
    else { Out-Line ' [ERROR] winws.exe exited during startup.' 'Red' }
    Out-Line ''
    Show-DriverBlock $rt $drv $bfe $sig $files $null -Compact
    if ($StartupCode -ge 0) {
        Out-KV 'Windows error' (Get-ErrorText $StartupCode) 'Red' 4
        Out-Line ''
        $staleNow = @(Get-StaleRecords $drv)
        if ($staleNow.Count -gt 0 -and $StartupCode -in @(2, 3, 1058, 1072)) {
            Out-Line '  Reason: a leftover WinDivert service record points to a deleted folder.' 'Yellow'
            foreach ($s in $staleNow) { Out-Line ('  Suggested action: ' + (Get-StaleAction $s)) 'Yellow' }
        } elseif ($ErrorKB.ContainsKey($StartupCode)) { Out-Line ('  Suggested action: ' + $ErrorKB[$StartupCode][2]) 'Yellow' }
    }
    if ($bfe.Status -ne 'Running') { Out-Line '  Base Filtering Engine is not running - WinDivert cannot work without it.' 'Yellow' }
    $sac = Get-SmartAppControl
    if ($StartupStage -eq 'launch' -and $sac -eq 'ON') { Out-Line '  Smart App Control is ON and blocks unsigned programs such as winws.exe.' 'Yellow' }
    Out-Line ''
    Out-Line '  Run DIAGNOSE.cmd (as administrator) for full details and a report to send.' 'Cyan'
    exit 0
}

# --------------------------------------------------------------------------------------------
# MODE: Preflight - INSTALL_AUTO.cmd readiness check (exit 0 = ok, 1 = blocking, 2 = warnings)
# --------------------------------------------------------------------------------------------
if ($Mode -eq 'Preflight') {
    $rt = Get-PrimaryRuntime
    $blocking = 0; $warn = 0
    Out-Line '  Pre-installation checks:'
    Out-KV 'Administrator' $(if ($script:IsAdmin) { 'YES' } else { 'NO' }) $(if ($script:IsAdmin) { 'Green' } else { 'Red' }) 4
    if (-not $script:IsAdmin) { $blocking++ }
    $files = Get-FileReport $rt
    $missing = @($files | Where-Object { -not $_.Exists -and $_.File -ne 'rotk_winws.conf' })
    $bad = @($files | Where-Object { $_.Exists -and $_.Hash -and -not $_.Match })
    if ($missing.Count -gt 0) { Out-KV 'Runtime files' ('MISSING: ' + (($missing | ForEach-Object { $_.File }) -join ', ')) 'Red' 4; $blocking++ }
    elseif ($bad.Count -gt 0) { Out-KV 'Runtime files' ('MODIFIED: ' + (($bad | ForEach-Object { $_.File }) -join ', ')) 'Yellow' 4; $warn++ }
    else { Out-KV 'Runtime files' 'OK (hashes match this release)' 'Green' 4 }
    $sig = Get-DriverSignature $rt
    if ($sig.Status -eq 'Valid') { Out-KV 'Driver signature' "VALID [$($sig.Signer)]" 'Green' 4 } else { Out-KV 'Driver signature' $sig.Status.ToUpper() 'Red' 4; $blocking++ }
    $bfe = Get-BfeState
    if ($bfe.Status -eq 'Running') { Out-KV 'BFE' 'RUNNING' 'Green' 4 }
    else { Out-KV 'BFE' "$($bfe.Status.ToUpper()) [$($bfe.StartType)] - WinDivert needs the Base Filtering Engine" 'Red' 4; $warn++ }
    $drv = Get-WinDivertState
    foreach ($s in (Get-StaleRecords $drv)) {
        Out-KV 'Stale WinDivert svc' "$($s.Name) -> $($s.ImagePath) [file missing] - causes driver error 2/3" 'Yellow' 4
        Out-Line ('      ' + (Get-StaleAction $s)) 'Yellow'
        $warn++
    }
    $sac = Get-SmartAppControl
    if ($sac -eq 'ON') { Out-KV 'Smart App Control' 'ON - may block unsigned winws.exe' 'Yellow' 4; $warn++ }
    $def = Get-DefenderHits
    if ($def.Hits.Count -gt 0) { Out-KV 'Defender history' "$($def.Hits.Count) detection(s) of project files" 'Yellow' 4; $warn++ }
    if ($blocking -gt 0) { exit 1 }
    if ($warn -gt 0) { exit 2 }
    exit 0
}

# --------------------------------------------------------------------------------------------
# MODE: Status - fast overview
# --------------------------------------------------------------------------------------------
if ($Mode -eq 'Status') {
    $rt = Get-PrimaryRuntime
    Out-Line ''
    Out-Line '======================================================================' 'Cyan'
    Out-Line ("            H1Z1 ROTK Russia - Status ($ProjectVersion)") 'Cyan'
    Out-Line '======================================================================' 'Cyan'
    if (-not $script:IsAdmin) { Out-Line '  [NOTE] Not elevated: some driver details may show UNKNOWN.' 'Yellow' }
    Out-Line ''
    $am = Get-AutoModeState
    if ($am.Installed) {
        Out-KV 'Auto Mode Task' "INSTALLED [$($am.State)] $($am.Version)" 'Gray'
        Out-KV 'Auto Watcher' $(if ($am.WatcherPid) { "RUNNING [PID: $($am.WatcherPid)]" } else { 'INACTIVE' }) $(if ($am.WatcherPid) { 'Green' } else { 'Yellow' })
        if ($am.NoTimeLimit -eq $false -or $am.Battery -eq $false) { Out-KV 'Task settings' 'legacy (72h limit / battery) - reinstall Auto Mode to fix' 'Yellow' }
    } else { Out-KV 'Auto Mode Task' 'NOT INSTALLED' 'Gray' }

    $game = @(Get-Process -Name 'H1Z1' -ErrorAction SilentlyContinue)
    Out-KV 'Game Process' $(if ($game.Count -gt 0) { 'RUNNING [H1Z1.exe]' } else { 'NOT RUNNING' }) 'Gray'

    $pw = Get-ProjectWinws
    Out-Line ''
    if ($pw.Project) {
        Out-KV 'H1Z1 ROTK Bypass' "ACTIVE [PID: $($pw.Project.Id)] [$($pw.Runtime.Label)]" 'Green'
        Out-KV 'Executable' $pw.Project.Path 'Gray'
    } else {
        $c = if ($game.Count -gt 0) { 'Red' } else { 'Gray' }
        Out-KV 'H1Z1 ROTK Bypass' 'INACTIVE' $c
    }
    if ($pw.Others.Count -gt 0) { Out-KV 'Other winws' (($pw.Others | ForEach-Object { "PID $($_.Id)" }) -join ', ') 'Yellow' }
    else { Out-KV 'Other winws' 'NOT DETECTED' 'Gray' }

    $fm = Read-FilterModel $rt.Filter
    if ($fm.Parsed) {
        $scope = ($fm.Ranges | ForEach-Object { if ($_[0] -eq $_[1]) { $_[0] } else { "$($_[0])-$($_[1])" } }) -join ', '
        $ports = ($fm.Ports | ForEach-Object { "$($_[0])-$($_[1])" }) -join ', '
        Out-KV 'Scope Filter' "$scope [UDP $ports]" 'Gray'
    }

    Out-Line ''
    Out-Line '  Driver' 'Cyan'
    $drv = Get-WinDivertState
    Show-DriverBlock $rt $drv (Get-BfeState) (Get-DriverSignature $rt) (Get-FileReport $rt) $pw.Project
    foreach ($r in $script:Runtimes) { [void](Show-LastStart $r) }

    $net = Get-NetworkModel
    $route = Resolve-RouteTo $net $KnownLoginIP
    if ($route) {
        $kind = if ($route.Adapter.Virtual) { 'VIRTUAL' } else { 'physical' }
        Out-Line ''
        Out-KV 'ROTK route' "$($route.Adapter.Alias) [$kind] via $($route.NextHop)" $(if ($route.Adapter.Virtual) { 'Yellow' } else { 'Gray' })
    }
    Out-Line ''
    Out-Line '  ROTK does not connect? Run DIAGNOSE.cmd as administrator.' 'Cyan'
    Out-Line '======================================================================' 'Cyan'
    exit 0
}

# --------------------------------------------------------------------------------------------
# MODE: Full
# --------------------------------------------------------------------------------------------
$started = Get-Date
$rt = Get-PrimaryRuntime
Out-Line '======================================================================' 'Cyan'
Out-Line ("          H1Z1 ROTK Russia - Diagnostic Report ($ProjectVersion)") 'Cyan'
Out-Line '======================================================================' 'Cyan'
$utcOff = [TimeZoneInfo]::Local.GetUtcOffset($started)
Out-Line ("  Generated : {0:yyyy-MM-dd HH:mm} (local time, UTC{1}{2:hh\.mm})" -f $started, $(if ($utcOff.Ticks -lt 0) { '-' } else { '+' }), $utcOff)
Out-Line '  Privacy   : user/PC names, personal paths, public IPs, IPv6 and tokens are removed.'

# A. SYSTEM ---------------------------------------------------------------------------------
Out-Section 'A. SYSTEM'
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
$osName = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
Out-KV 'Windows' ("{0} {1} (build {2}.{3})" -f $osName, $cv.DisplayVersion, $cv.CurrentBuildNumber, $cv.UBR)
Out-KV 'Architecture' $(if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86 (NOT SUPPORTED)' }) $(if ([Environment]::Is64BitOperatingSystem) { 'Gray' } else { 'Red' })
Out-KV 'Administrator' $(if ($script:IsAdmin) { 'YES' } else { 'NO' }) $(if ($script:IsAdmin) { 'Green' } else { 'Red' })
Out-KV 'PowerShell' $PSVersionTable.PSVersion.ToString()
if ([Environment]::Is64BitOperatingSystem) { Add-Check 'OK' 'Windows x64' } else { Add-Check 'FAIL' 'Windows is not 64-bit' '' 'WinDivert64.sys requires 64-bit Windows.' }
if ($script:IsAdmin) { Add-Check 'OK' 'Administrator' } else { Add-Check 'FAIL' 'Not running as administrator' 'driver and network details are incomplete' 'Right-click DIAGNOSE.cmd and choose "Run as administrator".' }

# B. PROJECT --------------------------------------------------------------------------------
Out-Section 'B. PROJECT'
Out-KV 'Diagnose version' $ProjectVersion
Out-KV 'Running from' $(if ($localRoot) { $localRoot } else { $scriptDir })
$filesOk = $true
foreach ($r in $script:Runtimes) {
    Out-Line ''
    Out-Line ("  Runtime [{0}] {1}" -f $r.Label, $r.Bin) 'Cyan'
    $fr = Get-FileReport $r
    foreach ($f in $fr) {
        if (-not $f.Exists) { Out-KV $f.File 'MISSING' 'Red' 4; $filesOk = $false }
        elseif ($f.Hash) { Out-KV $f.File $(if ($f.Match) { 'OK  ' + $f.Hash } else { 'MODIFIED ' + $f.Hash }) $(if ($f.Match) { 'Gray' } else { 'Yellow' }) 4; if (-not $f.Match) { $filesOk = $false } }
        else { Out-KV $f.File 'present' 'Gray' 4 }
    }
    $wp = Get-TrackedPid $r '.winws.pid'; $wa = Get-TrackedPid $r '.watcher.pid'
    Out-KV 'PID files' ("winws={0} watcher={1}" -f $(if ($wp) { $wp } else { '-' }), $(if ($wa) { $wa } else { '-' })) 'Gray' 4
}
if ($script:Runtimes.Count -eq 0) { Out-Line '  No runtime folder found next to this script.' 'Red'; $filesOk = $false }
if ($filesOk) { Add-Check 'OK' 'Project files' } else { Add-Check 'FAIL' 'Project files missing or modified' '' 'Re-download the release ZIP and extract ALL files. If files keep disappearing, antivirus is removing them.' }

$am = Get-AutoModeState
Out-Line ''
if ($am.Installed) {
    Out-KV 'Auto Mode' "INSTALLED [$($am.State)] installed version: $($am.Version)"
    Out-KV 'Watcher' $(if ($am.WatcherPid) { "RUNNING [PID $($am.WatcherPid)]" } else { 'NOT RUNNING' }) $(if ($am.WatcherPid) { 'Green' } else { 'Yellow' })
    if ($am.NoTimeLimit -eq $false -or $am.Battery -eq $false) {
        Out-KV 'Task settings' 'legacy: stops after 72 hours and/or does not run on battery' 'Yellow'
        Add-Check 'WARN' 'Auto Mode task uses legacy settings' '72h execution limit / battery restrictions' 'Run INSTALL_AUTO.cmd from this release once to update the task.'
    }
    if ($am.WatcherPid) { Add-Check 'OK' 'Auto Mode watcher' } else { Add-Check 'WARN' 'Auto Mode installed but watcher is not running' '' 'Sign out and back in, or run INSTALL_AUTO.cmd again.' }
} else { Out-KV 'Auto Mode' 'NOT INSTALLED (portable START.cmd mode)' }

$game = @(Get-Process -Name 'H1Z1' -ErrorAction SilentlyContinue)
if ($game.Count -gt 0) {
    $gameDirs = @($game | ForEach-Object { $gp = Get-ProcessPathSafe $_; if ($gp) { "'" + (Split-Path (Split-Path $gp -Parent) -Leaf) + "'" } else { 'path not readable' } }) -join ', '
    Out-KV 'H1Z1.exe' "RUNNING (game folder: $gameDirs)"
} else { Out-KV 'H1Z1.exe' 'NOT RUNNING' }
$pw = Get-ProjectWinws
if ($pw.Project) { Out-KV 'Project winws' "RUNNING [PID $($pw.Project.Id)] $($pw.Project.Path)" 'Green' }
else { Out-KV 'Project winws' 'NOT RUNNING' $(if ($game.Count -gt 0) { 'Red' } else { 'Gray' }) }
if ($game.Count -gt 0 -and -not $pw.Project) {
    Add-Check 'FAIL' 'winws is not running while H1Z1 is running' '' 'Start START.cmd (or check Auto Mode). If it fails, see the WinDivert section for the exact error.'
} elseif ($pw.Project) { Add-Check 'OK' 'winws' }
$lastStarts = @()
foreach ($r in $script:Runtimes) { $ls = Show-LastStart $r; if ($ls) { $lastStarts += $ls } }

$conf = if ($rt) { $rt.Conf } else { '' }
if ($conf -and (Test-Path -LiteralPath $conf)) {
    Out-Line ''
    Out-Line '  rotk_winws.conf:' 'Gray'
    foreach ($l in (Get-Content -LiteralPath $conf)) { Out-Line ('    ' + $l) 'Gray' }
}

# C. WINDIVERT ------------------------------------------------------------------------------
Out-Section 'C. WINDIVERT'
$drv = Get-WinDivertState -Deep
$bfe = Get-BfeState
$sig = Get-DriverSignature $rt
$fr = Get-FileReport $rt
Show-DriverBlock $rt $drv $bfe $sig $fr $pw.Project
Out-Line ''
Out-KV 'Detection sources' ("kernel-list={0}; signals={1}" -f $drv.KernelEnum, $(if ($drv.Signals) { $drv.Signals } else { 'none' })) 'Gray'
foreach ($k in $drv.Kernel) { Out-KV 'Kernel module' "$($k.Name) $($k.Path)" 'Gray' }
foreach ($d in $drv.Devices) { Out-KV 'SCM driver' "$($d.Name) [$($d.Status)]" 'Gray' }
foreach ($w in $drv.Wmi) { Out-KV 'Win32_SystemDriver' "$($w.Name) [$($w.State), $($w.StartMode)] $($w.Path)" 'Gray' }
foreach ($q in $drv.DriverQuery) { Out-KV 'driverquery' "$($q.Name) [$($q.State)]" 'Gray' }
foreach ($r in $drv.Records) { Out-KV 'Service record' ("{0} -> {1} [file {2}, start={3}, deleteflag={4}]" -f $r.Name, $r.ImagePath, $(if ($r.FileExists) { 'present' } else { 'MISSING' }), $r.Start, $r.DeleteFlag) 'Gray' }
foreach ($e in ($drv.Events | Select-Object -First 4)) { Out-KV 'Driver event' ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f $e.Time, $e.Text) 'Gray' }

if ($bfe.Status -eq 'Running') { Add-Check 'OK' 'BFE' } else { Add-Check 'FAIL' 'Base Filtering Engine is not running' "status $($bfe.Status), start type $($bfe.StartType)" $ErrorKB[1753][2] }
if ($sig.Status -ne 'Valid') { Add-Check 'FAIL' 'WinDivert64.sys signature is not valid' $sig.Status 'Re-download the release; the driver file is damaged or replaced.' }

$staleRecs = @(Get-StaleRecords $drv)
foreach ($s in $staleRecs) {
    Add-Check 'FAIL' 'Stale WinDivert service record points to a missing file' "$($s.Name) -> $($s.ImagePath)" (Get-StaleAction $s)
}

$errCodes = @()
foreach ($ls in $lastStarts) { if ($ls.Code -ge 0) { $errCodes += $ls.Code } }
foreach ($e in $drv.ScmErrors) { if ($null -ne $e.Code) { $errCodes += $e.Code } }
$errCodes = @($errCodes | Select-Object -Unique)
foreach ($c in $errCodes) {
    $kb = $ErrorKB[[int]$c]
    if ($kb) { Add-Check 'FAIL' ("WinDivert driver could not be loaded (error $c)") $kb[1] $kb[2] }
    else { Add-Check 'FAIL' ("winws/WinDivert start failed (code $c)") (Get-ErrorText $c) 'Send this report to the developer.' }
}

if ($pw.Project -and $drv.State -eq 'LOADED') { Add-Check 'OK' 'WinDivert' }
elseif ($pw.Project -and $drv.State -eq 'UNKNOWN') { Add-Check 'WARN' 'WinDivert state could not be confirmed' 'project winws is running but Windows driver state could not be resolved' 'Run DIAGNOSE.cmd as administrator.' }
elseif ($pw.Project -and $drv.State -eq 'NOT LOADED') { Add-Check 'FAIL' 'winws is running but no WinDivert driver is loaded' '' 'Restart the bypass (STOP.cmd then START.cmd). Send this report if it repeats.' }
elseif ($errCodes.Count -eq 0 -and $staleRecs.Count -eq 0 -and $bfe.Status -eq 'Running' -and $sig.Status -eq 'Valid') { Add-Check 'OK' 'WinDivert prerequisites' 'driver loads on demand when the bypass starts' }

# D. SECURITY -------------------------------------------------------------------------------
Out-Section 'D. SECURITY SOFTWARE / CODE INTEGRITY'
$sac = Get-SmartAppControl
$hvci = Get-MemoryIntegrity
Out-KV 'Smart App Control' $sac $(if ($sac -eq 'ON') { 'Yellow' } else { 'Gray' })
Out-KV 'Memory Integrity' $hvci
$ci = Get-CodeIntegrityEvents
if ($ci.Count -gt 0) {
    foreach ($e in $ci) { Out-KV 'Code Integrity' ('{0:yyyy-MM-dd HH:mm} event {1}: {2}' -f $e.Time, $e.Id, $e.Text) 'Red' }
    Add-Check 'FAIL' 'Windows Code Integrity blocked or flagged WinDivert/winws' "event $($ci[0].Id)" 'Windows refuses to load the driver (blocklist / HVCI / policy). The driver cannot be loaded on this PC while the policy is active.'
} else { Out-KV 'Code Integrity' 'no WinDivert-related block events (30 days)' 'Gray' }
$def = Get-DefenderHits
if (-not $def.Available) { Out-KV 'Defender history' 'not available (Defender off or another antivirus is used)' 'Gray' }
elseif ($def.Hits.Count -eq 0) { Out-KV 'Defender history' 'no detections of project files' 'Gray' }
else {
    foreach ($h in $def.Hits) { Out-KV 'Defender detection' ('{0:yyyy-MM-dd HH:mm} {1} [{2}] {3}' -f $h.Time, $h.Threat, $h.Action, $h.Resource) 'Red' }
    Add-Check 'FAIL' 'Defender detected project files' $def.Hits[0].Threat 'Restore the files from Protection History and add an exclusion for the project folder (WinDivert is commonly flagged as HackTool).'
}
if ($sac -eq 'ON') { Add-Check 'WARN' 'Smart App Control is ON' 'may block unsigned winws.exe / cygwin1.dll' $ErrorKB[4551][2] }

# E. CONFLICTS ------------------------------------------------------------------------------
Out-Section 'E. CONFLICTS (detected only, nothing is stopped)'
foreach ($o in $pw.Others) { Out-KV 'Other winws' "PID $($o.Id) $($o.Path)" 'Yellow' }
if ($pw.Others.Count -gt 0) { Add-Check 'WARN' 'Another winws (zapret) instance is running' "PIDs $(($pw.Others | ForEach-Object { $_.Id }) -join ',')" 'Two WinDivert tools can process the same ROTK packets. Close the other zapret while playing.' }
$conf2 = Get-ConflictInventory
foreach ($c in $conf2) { Out-KV $c.Name "running (PID $($c.Pids))" 'Gray' }
$otherConsumers = @($drv.Consumers | Where-Object { -not $pw.Project -or $_.Id -ne $pw.Project.Id })
foreach ($c in $otherConsumers) { Out-KV 'WinDivert consumer' "$($c.Name) PID $($c.Id)" 'Yellow' }
if ($conf2.Count -eq 0 -and $pw.Others.Count -eq 0 -and $otherConsumers.Count -eq 0) { Out-Line '  none detected' 'Gray' }
if (@($conf2 | Where-Object { $_.Name -in @('GoodbyeDPI', 'ExitLag (app)') }).Count -gt 0) {
    Add-Check 'WARN' 'GoodbyeDPI / ExitLag is running' '' 'Close it while playing ROTK with this project.'
}

# F. NETWORK --------------------------------------------------------------------------------
Out-Section 'F. NETWORK'
$net = Get-NetworkModel
$upAdapters = @($net.Adapters | Where-Object { $_.Status -eq 'Up' })
foreach ($a in $upAdapters) {
    $ai = Get-AdapterInfo $net ([int]$a.ifIndex)
    Out-KV $a.Name ("{0} | {1} | {2} | MTU {3} | if-metric {4}" -f $a.InterfaceDescription, $(if ($ai.Virtual) { 'virtual' } else { 'physical' }), $a.LinkSpeed, $ai.Mtu, $(if ([string]::IsNullOrEmpty([string]$ai.Metric)) { 'n/a' } else { $ai.Metric }))
}
Out-Line ''
$defaults = @($net.Defaults | Where-Object { $_.State -ne 'Unreachable' })
foreach ($d in $defaults) {
    $ai = Get-AdapterInfo $net ([int]$d.ifIndex)
    Out-KV 'Default route' ("{0} via {1} on {2} [{3}] route metric {4}, interface metric {5}" -f $d.DestinationPrefix, $d.NextHop, $ai.Alias, $(if ($ai.Virtual) { 'virtual' } else { 'physical' }), $d.RouteMetric, $(if ([string]::IsNullOrEmpty([string]$ai.Metric)) { 'n/a' } else { $ai.Metric }))
}
$internet = Resolve-RouteTo $net '1.1.1.1'
if ($internet) { Out-KV 'Internet traffic uses' ("{0} [{1}]" -f $internet.Adapter.Alias, $(if ($internet.Adapter.Virtual) { 'virtual / VPN / TUN' } else { 'physical' })) }
$physDefaults = @($defaults | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' -and -not (Get-AdapterInfo $net ([int]$_.ifIndex)).Virtual })
if ($physDefaults.Count -gt 1) {
    $effs = $physDefaults | ForEach-Object { [int]$_.RouteMetric + [int]((Get-AdapterInfo $net ([int]$_.ifIndex)).Metric) }
    if (@($effs | Select-Object -Unique).Count -lt $effs.Count) { Add-Check 'WARN' 'Multiple physical default routes with equal metric' '' 'Disconnect the unused adapter (for example Wi-Fi while on Ethernet).' }
}

$rotkRoutes = @()
foreach ($ip in @($KnownLoginIP, $KnownMatchIP)) {
    $r = Resolve-RouteTo $net $ip
    if ($r) { $rotkRoutes += $r }
}
Out-Line ''
foreach ($r in $rotkRoutes) {
    $label = if ($r.Ip -eq $KnownLoginIP) { 'ROTK login route' } else { 'ROTK match route' }
    Out-KV $label ("{0} -> {1} [{2}] via {3} (route {4}{5}) MTU {6}" -f $r.Ip, $r.Adapter.Alias, $(if ($r.Adapter.Virtual) { 'VIRTUAL' } else { 'physical' }), $r.NextHop, $r.Prefix, $(if ($r.Persistent) { ', persistent' } else { '' }), $r.Adapter.Mtu) $(if ($r.Adapter.Virtual) { 'Yellow' } else { 'Gray' })
}

# Persistent routes that cover ROTK destinations: are they still valid for the current network?
$netVerdicts = New-Object System.Collections.Generic.List[string]
$rotkPersistent = @($net.Persistent | Where-Object {
    $pfx = $_.DestinationPrefix.Split('/')
    (Test-InSubnet $KnownLoginIP $pfx[0] ([int]$pfx[1])) -or (Test-InSubnet $KnownMatchIP $pfx[0] ([int]$pfx[1])) -or (Test-IPInRange $pfx[0] $RotkSupernet[0] $RotkSupernet[1])
})
foreach ($p in $rotkPersistent) {
    $gws = @(); if ($net.Gateways.ContainsKey([int]$p.ifIndex)) { $gws = $net.Gateways[[int]$p.ifIndex] }
    $ai = Get-AdapterInfo $net ([int]$p.ifIndex)
    $onLink = $false
    foreach ($k in $net.IfAddr.Keys) { $x = $net.IfAddr[$k]; if ($x.Index -eq [int]$p.ifIndex -and (Test-InSubnet $p.NextHop $k $x.Prefix)) { $onLink = $true } }
    $valid = ($p.NextHop -eq '0.0.0.0') -or (($gws -contains $p.NextHop) -and $ai.Status -eq 'Up') -or ($onLink -and $ai.Status -eq 'Up')
    Out-KV 'Persistent route' ("{0} via {1} on {2} - {3}" -f $p.DestinationPrefix, $p.NextHop, $ai.Alias, $(if ($valid) { 'valid for current network' } else { 'STALE (gateway not on this network)' })) $(if ($valid) { 'Gray' } else { 'Red' })
    if (-not $valid) { $netVerdicts.Add('STALE_PERSISTENT_ROUTE') }
}
if ($rotkPersistent.Count -gt 0 -and $netVerdicts -notcontains 'STALE_PERSISTENT_ROUTE') {
    Add-Check 'WARN' 'Persistent ROTK routes are pinned to a fixed gateway' "$($rotkPersistent.Count) route(s), currently valid" 'They break when your router/ISP gateway changes. Prefer VPN-client exclusions (DIRECT rules / bypass list) over persistent routes.'
}
if ($netVerdicts -contains 'STALE_PERSISTENT_ROUTE') {
    Add-Check 'FAIL' 'Stale persistent route for ROTK' 'a saved route points to a gateway from a previous network' 'Delete the stale route (route delete <prefix>) or recreate it with the current gateway. DIAGNOSE does not change routes.'
}
foreach ($r in $rotkRoutes) {
    if ($r.Adapter.Virtual) { $netVerdicts.Add('TUN_ROUTE_CONFLICT') }
    elseif ($r.Adapter.Status -ne 'Up') { $netVerdicts.Add('WRONG_INTERFACE') }
}
if ($netVerdicts -contains 'TUN_ROUTE_CONFLICT') {
    Add-Check 'FAIL' 'ROTK traffic is routed into a VPN/TUN adapter' (($rotkRoutes | Where-Object { $_.Adapter.Virtual } | ForEach-Object { $_.Adapter.Alias }) -join ', ') 'Exclude H1Z1.exe / 162.19.94.95 / 162.19.126.0/24 from the VPN (DIRECT rule) or turn the VPN TUN mode off while playing.'
} elseif ($internet -and $internet.Adapter.Virtual) {
    Add-Check 'WARN' "VPN/TUN adapter owns the default route ($($internet.Adapter.Alias))" 'ROTK destinations are excluded and go direct' 'OK as long as ROTK stays excluded. Re-check after VPN client updates.'
}

# G. ROTK -----------------------------------------------------------------------------------
Out-Section 'G. ROTK ENDPOINTS & FILTER COVERAGE'
$fm = if ($rt) { Read-FilterModel $rt.Filter } else { Read-FilterModel '' }
Out-Line '  filter.txt:' 'Gray'
Out-Line ('    ' + $fm.Text) 'Gray'
Out-KV 'Known login/gateway' "$KnownLoginIP (UDP 20042-20045, 20140-20141)"
Out-KV 'Known match pool' '162.19.126.0/24 (UDP 20000-23000)'
$capture = $null
if ($game.Count -gt 0 -and -not $NoCapture -and $script:IsAdmin) {
    Out-Line ''
    Out-Line ("  H1Z1 is running - observing its UDP endpoints for {0} seconds (pktmon, read-only)..." -f $CaptureSeconds) 'Cyan'
    Out-Line '  Tip: stay in the lobby or in a match during this time.' 'Cyan'
    $capture = Invoke-GameCapture -GamePids @($game | ForEach-Object { $_.Id }) -Seconds $CaptureSeconds -net $net
} elseif ($game.Count -eq 0) {
    Out-KV 'Active endpoints' 'H1Z1 is not running - start the game and run DIAGNOSE again to verify live endpoints' 'Gray'
} elseif (-not $script:IsAdmin) {
    Out-KV 'Active endpoints' 'needs administrator rights' 'Yellow'
} else { Out-KV 'Active endpoints' 'capture disabled (-NoCapture)' 'Gray' }

$outside = @()
if ($capture) {
    if ($capture.Status -ne 'ok') { Out-KV 'Active endpoints' ("not observed: {0}" -f $capture.Reason) 'Yellow' }
    elseif ($capture.Flows.Count -eq 0) { Out-KV 'Active endpoints' 'no UDP traffic from H1Z1.exe observed during the capture window' 'Yellow' }
    else {
        Out-Line ''
        Out-Line '  Observed H1Z1.exe UDP flows (server endpoint -> classification):' 'Gray'
        foreach ($f in $capture.Flows) {
            $cls = Get-FlowClass $fm $f
            $label = switch ($cls) {
                'in-filter'   { 'ROTK, IN FILTER' }
                'region-ping' { 'data-center ping probe (other region, not gameplay)' }
                'outside'     { 'ROTK-LIKE, OUTSIDE FILTER' }
                default       { 'other (voice/Steam/etc.)' }
            }
            $rttTxt = if ($null -ne $f.PassiveRtt) { " | request->reply ~$($f.PassiveRtt) ms" } elseif ($f.Tx -gt 0 -and $f.Rx -gt 0) { ' | session flow (no request/reply pattern)' } else { '' }
            $line = ("    UDP -> {0}:{1}  tx {2} / rx {3} ({4} pkt/s) on {5} | {6}{7}" -f $f.Ip, $f.Port, $f.Tx, $f.Rx, $f.Pps, $f.Ifaces, $label, $rttTxt)
            Out-Line $line $(if ($cls -eq 'outside') { 'Red' } else { 'Gray' })
            if ($cls -eq 'outside') { $outside += $f }
        }
        $tunGame = @($capture.Flows | Where-Object { $_.Virtual -and (Get-FlowClass $fm $_) -in @('in-filter', 'outside') })
        $tunProbe = @($capture.Flows | Where-Object { $_.Virtual -and (Get-FlowClass $fm $_) -eq 'region-ping' })
        if ($tunGame.Count -gt 0) {
            $netVerdicts.Add('TUN_ROUTE_CONFLICT')
            Add-Check 'FAIL' 'ROTK game traffic observed inside a VPN/TUN adapter' (($tunGame | ForEach-Object { "$($_.Ip):$($_.Port)" }) -join ', ') 'Exclude H1Z1.exe and ROTK addresses from the VPN TUN or disable TUN mode while playing.'
        }
        if ($tunProbe.Count -gt 0) {
            Add-Check 'WARN' 'Ping probe to another ROTK region goes through the VPN/TUN' (($tunProbe | ForEach-Object { "$($_.Ip):$($_.Port)" }) -join ', ') 'Only the displayed ping of that other region is affected, not your game. Add the address to the VPN DIRECT rules if you want correct region pings.'
        }
    }
}
if ($outside.Count -gt 0) {
    $netVerdicts.Add('DIFFERENT_ROTK_SERVER')
    foreach ($o in $outside) { Out-Line ("  ACTIVE ROTK ENDPOINT OUTSIDE CURRENT FILTER: {0} port {1}" -f $o.Ip, $o.Port) 'Red' }
    Add-Check 'FAIL' 'ACTIVE ROTK ENDPOINT OUTSIDE CURRENT FILTER' (($outside | ForEach-Object { "$($_.Ip):$($_.Port)" }) -join ', ') 'Send this report to the developer - the ROTK infrastructure changed and the filter must be verified and extended.'
} elseif ($capture -and $capture.Status -eq 'ok' -and $capture.Flows.Count -gt 0) {
    $sawMatch = @($capture.Flows | Where-Object { (Get-FlowClass $fm $_) -eq 'in-filter' -and $_.Ip -ne $KnownLoginIP }).Count -gt 0
    Add-Check 'OK' 'ROTK filter coverage' $(if ($sawMatch) { 'all observed ROTK endpoints incl. the match server are inside filter.txt' } else { 'login/ping endpoints inside filter.txt; match server not observed (run DIAGNOSE during a match to verify it)' })
} elseif ($fm.Parsed) {
    Add-Check 'INFO' 'ROTK filter coverage' 'not verified live (game not running during diagnosis)'
} else {
    Add-Check 'WARN' 'filter.txt not recognized' '' 'Restore filter.txt from the release.'
}

# ROTK latency ------------------------------------------------------------------------------
Out-Section 'H. ROTK LATENCY'
$gwIp = $null
if ($rotkRoutes.Count -gt 0 -and $rotkRoutes[0].NextHop -ne '0.0.0.0') { $gwIp = $rotkRoutes[0].NextHop }
$gwIcmp = $null
if ($gwIp) { $gwIcmp = Measure-Icmp $gwIp -Count 10 -GapMs 50 }
$icmp = Measure-Icmp $KnownLoginIP -Count 25 -GapMs 150
$trace = Trace-Hops $KnownLoginIP
if ($gwIcmp) { Out-KV 'Gateway ICMP' $(if ($gwIcmp.Received -gt 0) { "min/avg/max {0}/{1}/{2} ms, loss {3}%" -f $gwIcmp.Min, $gwIcmp.Avg, $gwIcmp.Max, $gwIcmp.Loss } else { 'no reply' }) }
Out-KV 'Login host ICMP' $(if ($icmp.Received -gt 0) { "min/avg/max {0}/{1}/{2} ms, loss {3}% ({4} samples)" -f $icmp.Min, $icmp.Avg, $icmp.Max, $icmp.Loss, $icmp.Sent } else { 'no ICMP reply' })
if ($trace.Hops.Count -gt 0) {
    Out-KV 'Hop count' $(if ($trace.Reached) { $trace.HopCount } else { "destination not reached ($($trace.Hops.Count) hops answered)" })
    $prev = 0; $jump = $null
    foreach ($h in $trace.Hops) {
        $delta = $h.Ms - $prev
        if ($delta -gt 15 -and ($null -eq $jump -or $delta -gt $jump.Delta)) { $jump = [pscustomobject]@{ Hop = $h; Delta = $delta } }
        $prev = $h.Ms
    }
    $pathTxt = ($trace.Hops | ForEach-Object { "#{0}={1}ms" -f $_.Ttl, $_.Ms }) -join ' '
    Out-KV 'Path RTT by hop' $pathTxt
    if ($jump) { Out-KV 'Largest RTT step' ("+{0} ms at hop {1} ({2})" -f $jump.Delta, $jump.Hop.Ttl, $jump.Hop.Address) }
}
$matchIcmp = $null
$liveRotk = @()
$probes = @()
if ($capture -and $capture.Status -eq 'ok') {
    $liveRotk = @($capture.Flows | Where-Object { (Get-FlowClass $fm $_) -in @('in-filter', 'outside') })
    $probes = @($capture.Flows | Where-Object { (Get-FlowClass $fm $_) -eq 'region-ping' })
}
$matchFlow = $liveRotk | Where-Object { $_.Ip -ne $KnownLoginIP } | Select-Object -First 1
if ($matchFlow) {
    $matchIcmp = Measure-Icmp $matchFlow.Ip -Count 10 -GapMs 100
    Out-KV 'Match endpoint' ("{0}:{1}" -f $matchFlow.Ip, $matchFlow.Port)
    Out-KV 'Match host ICMP' $(if ($matchIcmp.Received -gt 0) { "min/avg/max {0}/{1}/{2} ms, loss {3}%" -f $matchIcmp.Min, $matchIcmp.Avg, $matchIcmp.Max, $matchIcmp.Loss } else { 'no ICMP reply (common for game servers)' })
} else { Out-KV 'Match endpoint' $(if ($game.Count -gt 0) { 'not observed (not in a match during capture)' } else { 'game not running' }) }
$udpRtts = @($liveRotk | Where-Object { $null -ne $_.PassiveRtt })
if ($udpRtts.Count -gt 0) { foreach ($u in $udpRtts) { Out-KV 'ROTK UDP (passive)' ("{0}:{1} request->reply ~{2} ms at the network adapter" -f $u.Ip, $u.Port, $u.PassiveRtt) } }
else { Out-KV 'ROTK UDP probe' 'not measured: no safe active UDP probe exists for the ROTK protocol (passive value appears only while the game runs)' }
foreach ($p in ($probes | Where-Object { $null -ne $_.PassiveRtt })) { Out-KV 'Other region (info)' ("{0}:{1} data-center ping ~{2} ms via {3}" -f $p.Ip, $p.Port, $p.PassiveRtt, $p.Ifaces) }
$gameLat = @(Get-GameReportedLatency)
if ($gameLat.Count -gt 0) {
    foreach ($g in $gameLat) { Out-KV 'Game-reported ping' ("session {0} UTC: {1} {2} ms (min {3}, max {4}, {5} samples)" -f $g.Start, $g.DataCenter, $g.Median, $g.Min, $g.Max, $g.Samples) }
} else { Out-KV 'Game-reported ping' 'no ROTK Launcher session data found (read it in game)' }
Out-Line '  Note: ICMP is not identical to the game UDP RTT; it shows the IP route latency.' 'DarkGray'

if ($gwIcmp -and $gwIcmp.Received -gt 0 -and $gwIcmp.Loss -ge 20) { $netVerdicts.Add('LOCAL_PACKET_LOSS'); Add-Check 'FAIL' 'Packet loss to your own router' "$($gwIcmp.Loss)% loss" 'Check the cable / Wi-Fi signal / router. This is local, not a ROTK or bypass problem.' }
elseif ($icmp.Received -gt 0 -and $icmp.Loss -ge 20) { Add-Check 'WARN' 'ICMP loss on the route to ROTK' "$($icmp.Loss)% of $($icmp.Sent) probes" 'Loss on the ISP route; repeat later. Routers also rate-limit ICMP, so confirm with in-game packet loss.' }

$latestGame = $gameLat | Select-Object -First 1
if ($icmp.Received -gt 0) {
    $txt = "ICMP route RTT to ROTK login host ~$($icmp.Avg) ms"
    if ($latestGame) {
        $diff = $latestGame.Median - $icmp.Avg
        if ($diff -gt 20) {
            Add-Check 'WARN' ("Game ping ({0} ms) is {1} ms above the IP route RTT ({2} ms)" -f $latestGame.Median, $diff, $icmp.Avg) 'the extra delay is not in the IP route to the login host' 'Run DIAGNOSE while in the ROTK lobby so the live UDP endpoints and request->reply delay can be measured; send the report.'
        } else {
            Add-Check 'INFO' ("Latency ~{0} ms (game) / ~{1} ms (ICMP)" -f $latestGame.Median, $icmp.Avg) 'game latency matches the network route' 'Latency is a property of your ISP route to the ROTK data center; the bypass does not change routing.'
        }
    } else { Add-Check 'INFO' $txt 'route latency only; game ping not available' 'Latency depends on your ISP route; the bypass does not change routing.' }
}

# Network verdict category
$order = @('TUN_ROUTE_CONFLICT', 'STALE_PERSISTENT_ROUTE', 'WRONG_INTERFACE', 'DIFFERENT_ROTK_SERVER', 'LOCAL_PACKET_LOSS')
$script:Verdict = 'ROUTE_OK'
foreach ($v in $order) { if ($netVerdicts -contains $v) { $script:Verdict = $v; break } }
if ($rotkRoutes.Count -eq 0) { $script:Verdict = 'UNKNOWN' }

# RESULT ------------------------------------------------------------------------------------
Out-Line ''
Out-Line '======================================================================' 'Cyan'
Out-Line ' DIAGNOSTIC RESULT' 'Cyan'
Out-Line '======================================================================' 'Cyan'
$rank = @{ 'FAIL' = 0; 'WARN' = 1; 'OK' = 2; 'INFO' = 3 }
$sorted = $script:Checks | Sort-Object { $rank[$_.Level] }
foreach ($c in $sorted) {
    $tag = '[{0}]' -f $c.Level
    $d = if ($c.Detail) { " - $($c.Detail)" } else { '' }
    Out-Line (" {0,-7}{1}{2}" -f $tag, $c.Name, $d) (Get-LevelColor $c.Level)
}
Out-Line ''
Out-Line (" Network verdict: {0}" -f $script:Verdict) $(if ($script:Verdict -eq 'ROUTE_OK') { 'Green' } else { 'Yellow' })
Out-Line ''
$actions = @($sorted | Where-Object { $_.Action -and $_.Level -in @('FAIL', 'WARN') } | ForEach-Object { $_.Action } | Select-Object -Unique)
Out-Line ' Suggested action:' 'Cyan'
if ($actions.Count -eq 0) {
    if ($game.Count -gt 0 -and $pw.Project) { Out-Line '  No local bypass failure detected. Latency is defined by your ISP route to ROTK.' 'Green' }
    else { Out-Line '  No problems detected. Start H1Z1; if it does not connect, run DIAGNOSE.cmd again while the game is open.' 'Green' }
} else {
    $n = 1
    foreach ($a in $actions) { Out-Line ("  {0}. {1}" -f $n, $a) 'Yellow'; $n++ }
}
Out-Line ''
Out-Line (" Diagnosis took {0:N0} s. Project: https://github.com/Blaykosik/H1Z1-ROTK-Russia" -f ((Get-Date) - $started).TotalSeconds)
Out-Line '======================================================================' 'Cyan'

# Write the sanitized report (each line was already sanitized; run once more on the whole text).
$reportText = Protect-Text (($script:Lines) -join "`r`n")
$targets = @()
if ($ReportDir) { $targets += $ReportDir.TrimEnd('.').TrimEnd('\') }
$targets += [Environment]::GetFolderPath('Desktop')
$written = $null
foreach ($d in $targets) {
    if (-not $d) { continue }
    try {
        $path = Join-Path $d 'diagnostic-report.txt'
        [System.IO.File]::WriteAllText($path, $reportText + "`r`n", (New-Object System.Text.UTF8Encoding($true)))
        $written = $path; break
    } catch {}
}
Write-Host ''
if ($written) {
    Write-Host ' Report saved to:' -ForegroundColor Cyan
    Write-Host ("   $written") -ForegroundColor White
    Write-Host ' Attach diagnostic-report.txt to your GitHub issue or Telegram message.' -ForegroundColor Cyan
    Write-Host ' It contains no user/PC names, personal paths, public IPs or tokens.' -ForegroundColor Cyan
} else {
    Write-Host ' [ERROR] Could not write diagnostic-report.txt (folder not writable).' -ForegroundColor Red
}
$fails = @($script:Checks | Where-Object { $_.Level -eq 'FAIL' }).Count
if ($fails -gt 0) { exit 1 }
exit 0

# H1Z1 ROTK Russia - Privacy gate for diagnostic-report.txt (v1.3.0)
#
# 1. Runs the sanitizer self-test with planted secrets.
# 2. Generates a real report on this machine (or scans -ReportPath) and searches it for
#    anything that identifies the user: account/PC names, SID, personal paths, public or
#    local-public IPs, IPv6, Steam IDs, UUIDs, proxy links, subscription URLs, tokens, e-mail.
# Exit code 0 = report is safe to publish, 1 = leak found.

param(
    [string]$ReportPath = '',
    [switch]$WithCapture
)

$ErrorActionPreference = 'Stop'
$engine = Join-Path $PSScriptRoot 'diagnose.ps1'
$failures = New-Object System.Collections.Generic.List[string]

Write-Host '[1/3] Sanitizer self-test with planted secrets...'
$selfTest = & powershell -NoProfile -ExecutionPolicy Bypass -File $engine -Mode SanitizerTest
if ($LASTEXITCODE -ne 0) { $failures.Add('sanitizer self-test: ' + ($selfTest | Select-Object -Last 1)) }

if (-not $ReportPath) {
    Write-Host '[2/3] Generating a real diagnostic report on this machine...'
    $tmp = Join-Path $env:TEMP ('rotk-privacy-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $extra = @(); if (-not $WithCapture) { $extra += '-NoCapture' }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $engine -Mode Full -ReportDir $tmp @extra *> $null
    $ReportPath = Join-Path $tmp 'diagnostic-report.txt'
}
if (-not (Test-Path $ReportPath)) { Write-Host "[FAIL] report not found: $ReportPath" -ForegroundColor Red; exit 1 }
$text = [System.IO.File]::ReadAllText($ReportPath)

Write-Host '[3/3] Scanning report for identifying data...'
function Test-Literal([string]$label, [string]$value) {
    if ([string]::IsNullOrWhiteSpace($value) -or $value.Length -lt 2) { return }
    if ([regex]::IsMatch($text, '(?i)(?<![A-Za-z0-9])' + [regex]::Escape($value) + '(?![A-Za-z0-9])')) { $failures.Add("$label found: $value") }
}
function Test-Pattern([string]$label, [string]$pattern, [scriptblock]$allow = $null) {
    foreach ($m in [regex]::Matches($text, $pattern)) {
        if ($allow -and (& $allow $m.Value)) { continue }
        $failures.Add("$label found: $($m.Value)")
    }
}

Test-Literal 'user name' $env:USERNAME
Test-Literal 'computer name' $env:COMPUTERNAME
if ($env:USERDOMAIN -ne $env:COMPUTERNAME -and $env:USERDOMAIN -ne 'WORKGROUP') { Test-Literal 'user domain' $env:USERDOMAIN }
try { Test-Literal 'user SID' ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value) } catch {}
try { Test-Literal 'profile path' $env:USERPROFILE } catch {}

# Every address configured on this PC that is public (v4) or global (v6) must be absent.
foreach ($a in (Get-NetIPAddress -ErrorAction SilentlyContinue)) {
    $ip = $a.IPAddress -replace '%\d+$', ''
    if ($a.AddressFamily -eq 'IPv6' -and $ip -notmatch '^(fe80|::1)') { Test-Literal 'local IPv6 address' $ip }
    if ($a.AddressFamily -eq 'IPv4' -and $ip -notmatch '^(10\.|127\.|192\.168\.|169\.254\.|172\.(1[6-9]|2\d|3[01])\.|100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.)') { Test-Literal 'local public IPv4' $ip }
}

Test-Pattern 'absolute path' '(?i)\b[a-z]:\\(?!\.\.\.)[^\s<>"]+'
Test-Pattern 'user profile path' '(?i)\\Users\\[^\\\s]+'
Test-Pattern 'SID' '\bS-1-5-21-[\d-]+'
Test-Pattern 'Steam ID' '\b7656119\d{10}\b'
Test-Pattern 'UUID' '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'
Test-Pattern 'proxy link' '(?i)\b(vless|vmess|trojan|ss|ssr|hysteria2?|tuic)://'
Test-Pattern 'Reality/VLESS parameter' '(?i)\b(pbk|publicKey|shortId|realitySettings|flow=xtls)\b'
Test-Pattern 'e-mail' '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
Test-Pattern 'URL' '(?i)\bhttps?://\S+' { param($v) $v -match '(?i)^https?://(www\.)?github\.com/Blaykosik/' }
Test-Pattern 'IPv6 address' '(?i)\b(?:[0-9a-f]{1,4}:){3,7}[0-9a-f]{1,4}\b'
Test-Pattern 'token-like string' '\b[A-Za-z0-9+/_-]{32,}={0,2}' { param($v) ($v -match '^[0-9A-F]{64}$') -or -not ($v -match '\d' -and $v -match '[A-Za-z]') }

# Public IPv4: only ROTK (162.19.0.0/16) or server endpoints listed on "UDP ->" flow lines may stay.
$flowIps = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($m in [regex]::Matches($text, 'UDP -> (\d{1,3}(?:\.\d{1,3}){3}):')) { [void]$flowIps.Add($m.Groups[1].Value) }
Test-Pattern 'public IPv4' '(?<![\d.])(\d{1,3}\.){3}\d{1,3}(?![\d]|\.\d)' {
    param($v)
    $o = $v.Split('.') | ForEach-Object { [int]$_ }
    if (@($o | Where-Object { $_ -gt 255 }).Count -gt 0) { return $true }
    if ($o[0] -in 10, 127, 0 -or ($o[0] -eq 192 -and $o[1] -eq 168) -or ($o[0] -eq 172 -and $o[1] -ge 16 -and $o[1] -le 31) -or ($o[0] -eq 169 -and $o[1] -eq 254) -or ($o[0] -eq 100 -and $o[1] -ge 64 -and $o[1] -le 127) -or $o[0] -ge 224) { return $true }
    if ($o[0] -eq 162 -and $o[1] -eq 19) { return $true }
    return $flowIps.Contains($v)
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "[FAIL] $($failures.Count) potential leak(s) in $ReportPath" -ForegroundColor Red
    $failures | Select-Object -Unique | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "[OK] Report is safe to publish: $ReportPath" -ForegroundColor Green
exit 0

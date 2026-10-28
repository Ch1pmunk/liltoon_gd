<#
    Compiled-variant checker with crash-resilient progress log.

    Why this exists: running many Godot instances back to back can take the
    whole system down (0x139 bugcheck, see ROADMAP RISKS). A plain loop loses
    every result because stdout dies with the process. This script appends one
    line per shader immediately, so after a hard reset the log still tells you
    exactly which shader was running when it died.

    Usage:
        powershell -ExecutionPolicy Bypass -File tools\check_all_shaders.ps1
        powershell -ExecutionPolicy Bypass -File tools\check_all_shaders.ps1 -Start 5 -End 9 -DelaySec 120
        powershell -ExecutionPolicy Bypass -File tools\check_all_shaders.ps1 -ListOnly

    Run it from a terminal you keep open. Do NOT launch it with Start-Process from an
    agent shell: that child process gets torn down when the agent session ends, leaving
    the run truncated without any error in the log (observed 2026-10-27: stopped after
    index 20 with the machine perfectly healthy).

    Read the log afterwards:  Get-Content docs\evidence\compile_check.log
#>
param(
    [int]$Start = 0,
    [int]$End = 27,
    [int]$DelaySec = 60,
    [string]$LogPath = "docs\evidence\compile_check.log",
    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'
$godot = if ($env:GODOT_EXE) { $env:GODOT_EXE } else {
    'C:\Users\zzh13\Desktop\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
}
$scene = 'res://tools/compile_check.tscn'

if (-not (Test-Path $godot)) { throw "Godot executable not found: $godot" }

# Make the log path absolute against the project root.
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($LogPath)) {
    $LogPath = Join-Path $projectRoot $LogPath
}
$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

if ($ListOnly) {
    # 原生程序写 stderr 时, PS 5.1 在 ErrorActionPreference=Stop 下会把它当终止错误;
    # Godot 的正常提示(例如缺失 icon)不应中断列表。
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $listing = & $godot --path $projectRoot $scene --quit-after 1 -- --list 2>&1 |
        Select-String -Pattern 'COMPILE_CHECK_LIST\s+(\S+)'
    $ErrorActionPreference = $prevEap
    $index = 0
    foreach ($match in $listing) {
        '{0,2}  {1}' -f $index, $match.Matches.Groups[1].Value
        $index++
    }
    return
}

if ($Start -lt 0) { $Start = 0 }
if ($End -lt $Start) { throw "-End must be >= -Start" }

"# run start $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  range=$Start..$End  delay=${DelaySec}s" |
    Add-Content -Path $LogPath -Encoding UTF8

for ($i = $Start; $i -le $End; $i++) {
    $stamp = Get-Date -Format 'HH:mm:ss'
    # Write the "about to run" marker first: if the machine dies here, the last
    # line in the log is exactly the shader that was loading.
    "$stamp`tSTART`t$i" | Add-Content -Path $LogPath -Encoding UTF8

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $godot --path $projectRoot $scene --quit-after 10 --resolution 640x360 -- --index=$i 2>&1
    $ErrorActionPreference = $prevEap
    $matched = ($output | Select-String -Pattern 'COMPILE_CHECK name=(\S+)')
    $name = if ($matched) { $matched.Matches.Groups[1].Value } else { "index$i" }
    $errors = ($output | Select-String -Pattern 'SHADER ERROR').Count
    $done = ($output | Select-String -Pattern 'COMPILE_CHECK_DONE').Count
    $tag = if ($errors -gt 0) { 'FAIL' } elseif ($done -gt 0) { 'OK' } else { 'INCOMPLETE' }

    "$stamp`t$tag`t$i`t$name`t$($output.Count) lines" | Add-Content -Path $LogPath -Encoding UTF8

    if ($i -lt $End) { Start-Sleep -Seconds $DelaySec }
}

"# run end $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogPath -Encoding UTF8
Write-Output "Log written to $LogPath"

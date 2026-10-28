<#
    Run the headless smoke test with a hard timeout.

    2026-10-28:调用 `godot --headless -s res://tools/smoke_test.gd` 时,
    Godot 进程曾卡住超过 5 分钟不退出(两次调用各留一个僵尸进程).
    headless 本身不创建窗口, 所以"没有窗口"不代表卡住, 但"长时间不返回"就是卡住.
    凡是跑冒烟, 一律走这个脚本, 不要直接调 godot.

    Usage:
        powershell -ExecutionPolicy Bypass -File tools\smoke.ps1
        powershell -ExecutionPolicy Bypass -File tools\smoke.ps1 -TimeoutSec 180
#>
param([int]$TimeoutSec = 120)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$godot = if ($env:GODOT_EXE) { $env:GODOT_EXE } else {
    'C:\Users\zzh13\Desktop\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
}
if (-not (Test-Path $godot)) { throw "Godot executable not found: $godot (set GODOT_EXE)" }
$outFile = Join-Path $env:TEMP 'liltoon_smoke_out.txt'
$errFile = Join-Path $env:TEMP 'liltoon_smoke_err.txt'

foreach ($f in @($outFile, $errFile)) { if (Test-Path $f) { Remove-Item $f -Force } }

$proc = Start-Process -FilePath $godot `
    -ArgumentList '--headless', '--path', "`"$root`"", '-s', 'res://tools/smoke_test.gd' `
    -WorkingDirectory $root -NoNewWindow -PassThru `
    -RedirectStandardOutput $outFile -RedirectStandardError $errFile

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$finished = $proc.WaitForExit($TimeoutSec * 1000)

if ($finished) {
    $sw.Stop()
    Get-Content $outFile, $errFile -ErrorAction SilentlyContinue |
        Select-String -Pattern '冒烟测试|失败|SHADER ERROR|SCRIPT ERROR' |
        ForEach-Object { $_.Line.Trim() }
    Write-Output ("SMOKE_DONE exit=$($proc.ExitCode) elapsed=$([math]::Round($sw.Elapsed.TotalSeconds,1))s")
} else {
    try { $proc.Kill(); $proc.WaitForExit(5000) } catch {}
    $sw.Stop()
    Write-Output ("SMOKE_TIMEOUT after $($TimeoutSec)s -- process killed")
    Write-Output '--- last output ---'
    Get-Content $outFile, $errFile -ErrorAction SilentlyContinue | Select-Object -Last 12
    exit 2
}

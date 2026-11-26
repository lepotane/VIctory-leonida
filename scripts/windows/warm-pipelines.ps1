<#
.SYNOPSIS
    Pre-warms the D3D12 PSO (host pipeline) cache in %LOCALAPPDATA%\VIctory\cache-pareto
    so in-game shader/PSO stutters are minimized.
.EXAMPLE
    .\scripts\windows\warm-pipelines.ps1
    .\scripts\windows\warm-pipelines.ps1 -All
#>
param(
    [string]$VictoryExe = '',
    [switch]$All
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($VictoryExe)) {
    $VictoryExe = Join-Path $repoRoot 'target\release\victory.exe'
}

if (-not (Test-Path $VictoryExe)) {
    throw "Release binary not found at $VictoryExe. Build first from repo root: cargo build --release --locked -p victory"
}

$env:VICTORY_CACHE_DIR = Join-Path $env:LOCALAPPDATA 'VIctory\cache-pareto'
Write-Host "Pipeline cache: $env:VICTORY_CACHE_DIR" -ForegroundColor Cyan

$warmArgs = @('warm')
if (-not $All) {
    $warmArgs += '--used'
}

& $VictoryExe @warmArgs
exit $LASTEXITCODE

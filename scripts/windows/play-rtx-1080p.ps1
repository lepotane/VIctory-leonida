<#
.SYNOPSIS
    Launches Xbox Series S builds on Windows 11 x64 at 1920x1080 (RTX-tuned preset)
    with parallel list translation (VICTORY_THIN), GPU card steps (VICTORY_CARD_STEPS=2),
    ahead texture uploads (VICTORY_UPLOAD_AHEAD=1), and Smooth Motion DRS support.
.EXAMPLE
    $env:VICTORY_GAME_DIR = 'D:\Games\MyDump'
    .\scripts\windows\play-rtx-1080p.ps1 -SmoothMotion
.EXAMPLE
    .\scripts\windows\play-rtx-1080p.ps1 -GameExe 'D:\Games\MyDump\game_scarlett_master.exe' -DisplayMode 1920x1080 -ManualMenus
#>
param(
    [string]$GameExe = '',
    [string]$VictoryExe = '',
    [string]$DisplayMode = '1920x1080',
    [hashtable]$ExtraEnv = @{},
    [switch]$Cap60,
    [switch]$Windowed,
    [switch]$ManualMenus,
    [switch]$Wait,
    [switch]$VerboseLog,
    # Driver frame interpolation at low base FPS (~5-15 FPS) can warp faces or cause
    # glowing eyes/artifacts; at ~18-24 native FPS it typically doubles smoothness cleanly.
    [switch]$SmoothMotion,
    [switch]$NoPanel,
    # Real ray-traced indirect light. Off by default on RTX (wave32 builder instability).
    [switch]$RT
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

if ([string]::IsNullOrWhiteSpace($GameExe)) {
    if (-not [string]::IsNullOrWhiteSpace($env:VICTORY_GAME_EXE)) {
        $GameExe = $env:VICTORY_GAME_EXE
    } elseif (-not [string]::IsNullOrWhiteSpace($env:VICTORY_GAME_DIR)) {
        $GameExe = Join-Path $env:VICTORY_GAME_DIR 'game_scarlett_master.exe'
    } else {
        throw "Game executable not specified. Pass -GameExe '<path>\game_scarlett_master.exe' or set `$env:VICTORY_GAME_DIR / `$env:VICTORY_GAME_EXE."
    }
}
if (-not (Test-Path $GameExe)) { throw "Game executable not found: $GameExe" }

$targetRelease = Join-Path $repoRoot 'target\release'
$defaultAliasExe = Join-Path $targetRelease 'victory_rtx.exe'
$builtExe = Join-Path $targetRelease 'victory.exe'

if ([string]::IsNullOrWhiteSpace($VictoryExe)) {
    $VictoryExe = $defaultAliasExe
}

if ($VictoryExe -eq $defaultAliasExe -and (Test-Path $builtExe)) {
    $needsSync = -not (Test-Path $VictoryExe) -or ((Get-Item $builtExe).LastWriteTimeUtc -gt (Get-Item $VictoryExe).LastWriteTimeUtc)
    if ($needsSync) {
        Copy-Item -Path $builtExe -Destination $VictoryExe -Force
    }
}

if (-not (Test-Path $VictoryExe)) {
    throw "Release binary not found at $VictoryExe. Build first from repo root: cargo build --release --locked -p victory"
}

# Clear inherited VICTORY_* environment variables for a deterministic launch.
Get-ChildItem Env: | Where-Object { $_.Name -like 'VICTORY_*' } | ForEach-Object { Remove-Item "Env:$($_.Name)" }

$smScript = Join-Path $PSScriptRoot 'smooth-motion.ps1'
if (Test-Path $smScript) {
    $smState = if ($SmoothMotion) { 'on' } else { 'off' }
    & powershell -ExecutionPolicy Bypass -File $smScript -State $smState -Exe $VictoryExe | Out-Host
}

$cacheDir = Join-Path $env:LOCALAPPDATA 'VIctory\cache-pareto'

$turbo = [ordered]@{
    VICTORY_CACHE_DIR             = $cacheDir
    VICTORY_DISPLAY_MODE          = $DisplayMode
    VICTORY_TEXTURE_NO_WAIT       = '1'
    VICTORY_RELAY                 = '2'
    VICTORY_WIDE_BACK             = '1'
    VICTORY_CARD_REHASH_RUNS      = '1'
    VICTORY_JOIN_COPIES           = '1'
    VICTORY_INDIRECT_WINDOW       = '1'
    VICTORY_RELAY_COPY            = '1'
    VICTORY_CARD_STEPS            = '2'
    VICTORY_INDIRECT_BATCH        = '2'
    VICTORY_MAP_THREADS           = '1'
    VICTORY_TITLE_PRIORITIES      = '0'
    VICTORY_CARD_AWAKE            = '1'
    VICTORY_SHOW_AFTER            = '1'
    VICTORY_THIN                  = '1'
    VICTORY_JOIN_PARTS            = '8'
    VICTORY_UPLOAD_AHEAD          = '1'
    VICTORY_LEVELS_ON_DEMAND      = '1'
    VICTORY_CARD_BUFFERS_MIN_KB   = '64'

    # 16 GB VRAM / Bake Safety / Keep under local VRAM budget
    VICTORY_CARD_WINDOWS_MB       = '512'
    VICTORY_CARD_BUFFERS_MB       = '1024'
    VICTORY_TEXTURE_KEEP          = '0'
    VICTORY_TEXTURE_ROOM_PERCENT  = '88'
    VICTORY_BAKE_EXACT            = '1'
    VICTORY_BAKE_TEXTURES_MS      = '20000'
    VICTORY_EARLY_TEXTURES_MS     = '40'

    # Threading & Flight Queue (tune VICTORY_FAST_CORES to match your CPU topology)
    VICTORY_FAST_CORES            = '3'
    VICTORY_THIN_THREADS          = '8'
    VICTORY_UNDER_THREADS         = '6'
    VICTORY_VIEW_THREADS          = '6'
    VICTORY_LAND_THREADS          = '6'
    VICTORY_SUBMIT_DEPTH          = '96'
    VICTORY_LATE_WAIT_LISTS       = '512'
    VICTORY_MERGE_RUNS            = '4096'

    # Anti-Stutter, Dead RT Skip & Pipeline Pre-warming
    VICTORY_PIPELINE_BOOK         = '1'
    VICTORY_DYNAMIC_SLOTS         = '524288'
    VICTORY_PIPELINE_WAIT_MS      = '10000'
    VICTORY_PIPELINE_WORKERS      = '12'
    VICTORY_SKIP_DEAD_RT          = '1'
    VICTORY_BVH_MISS              = '1'

    # Indirect Ambient Calibration, Night/Indoor Floor, Specular Cleaning, CAS Sharpen
    VICTORY_AMBIENT               = '1.5'
    VICTORY_AMBIENT_FLOOR         = '0.42'
    VICTORY_AMBIENT_SHADE         = '0.70,0.65'
    VICTORY_AMBIENT_AIR           = '1.2'
    VICTORY_AMBIENT_REFLECT       = '0.30'
    VICTORY_AMBIENT_REFLECT_CLEAN = '1'
    VICTORY_COMPOSE_SHARPEN       = '0.50'
    VICTORY_SHADOW_LIFT           = '0.20'

    # Top-left live FPS / Smooth Motion HUD (toggle anytime with F3)
    VICTORY_PANEL                 = $(if ($NoPanel) { '0' } else { '1' })

    VICTORY_FRAME_INTERVAL_US     = $(if ($Cap60) { '16667' } else { '0' })
    VICTORY_SWAP_BUFFERS          = '3'
    VICTORY_ALLOW_TEARING         = '0'
    VICTORY_BORDERLESS            = $(if ($Windowed) { '0' } else { '1' })
    VICTORY_LOG                   = $(if ($VerboseLog) { 'info' } else { 'warn' })
}

if ($RT) {
    $turbo['VICTORY_BVH_BUILDER'] = '1'
    $turbo['VICTORY_SKIP_DEAD_RT'] = '0'
    $turbo['VICTORY_AMBIENT'] = 'off'
}

foreach ($name in $turbo.Keys) { Set-Item -Path "Env:$name" -Value $turbo[$name] }
$env:RUST_LOG = $turbo.VICTORY_LOG

if (-not $ManualMenus) {
    $env:VICTORY_KEYS = '4:Enter,8:Enter,12:Enter,16:Enter,20:Enter,24:Enter,28:Enter,32:Enter,36:Enter,40:Enter,44:Enter,48:Enter'
}

foreach ($name in $ExtraEnv.Keys) { Set-Item -Path "Env:$name" -Value ([string]$ExtraEnv[$name]) }

$runsDir = Join-Path $env:LOCALAPPDATA 'VIctory\runs'
New-Item -ItemType Directory -Force -Path $runsDir | Out-Null
$outLog = Join-Path $runsDir 'play-rtx-1080p-latest.out.log'
$errLog = Join-Path $runsDir 'play-rtx-1080p-latest.err.log'

$proc = Start-Process -FilePath $VictoryExe `
    -ArgumentList @('run', $GameExe, '--execute', '--console', 'series-s') `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError $errLog `
    -PassThru

$windowReady = $false
for ($i = 0; $i -lt 16; $i++) {
    Start-Sleep -Milliseconds 500
    $proc.Refresh()
    if ($proc.HasExited) { break }
    if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
        $windowReady = $true
        break
    }
}

if ($proc.HasExited) {
    $exeName = Split-Path $VictoryExe -Leaf
    Write-Host "ERROR: $exeName exited early (ExitCode=$($proc.ExitCode)). Tail of stderr log:" -ForegroundColor Red
    if (Test-Path $errLog) {
        Get-Content $errLog -Tail 25
    }
    exit $proc.ExitCode
}

$smoothLoaded = $false
try {
    Start-Sleep -Milliseconds 500
    $mods = (Get-Process -Id $proc.Id -ErrorAction Stop).Modules
    if ($mods | Where-Object { $_.ModuleName -ieq 'NvPresent64.dll' }) {
        $smoothLoaded = $true
    }
} catch {
}

Write-Host "=== VIctory Started (RTX 1080p Preset / Xbox Series S) ===" -ForegroundColor Green
Write-Host ("PID          : {0}" -f $proc.Id)
Write-Host ("Exe          : {0}" -f $VictoryExe)
Write-Host ("Profile      : series-s (DisplayMode=$DisplayMode, Borderless=$($env:VICTORY_BORDERLESS), SwapBuffers=$($env:VICTORY_SWAP_BUFFERS), Tearing=$($env:VICTORY_ALLOW_TEARING))")
Write-Host ("Window       : {0}" -f $(if ($windowReady) { "Ready (HWND=$($proc.MainWindowHandle))" } else { "Initializing..." }))
if ($smoothLoaded -and -not $SmoothMotion) {
    Write-Host "Smooth Motion: ACTIVE (DRIVER) - keep off unless base FPS >= ~18-20" -ForegroundColor Yellow
} elseif ($smoothLoaded) {
    Write-Host "Smooth Motion: ACTIVE (-SmoothMotion enabled)" -ForegroundColor Cyan
} else {
    Write-Host "Smooth Motion: INACTIVE" -ForegroundColor Green
}
Write-Host "Controls     : Enter=A | Backspace=B | Y=Y | X=X | Arrows=D-Pad | WASD=LS | IJKL=RS | Esc=Menu"
Write-Host "Overlays     : F3 = Built-in FPS/HUD | Alt+R = NVIDIA Overlay (Smooth Motion OUT FPS)"
Write-Host "Stderr Log   : $errLog"

if ($Wait) {
    $proc.WaitForExit()
    exit $proc.ExitCode
}

exit 0

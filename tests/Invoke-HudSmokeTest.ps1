<#
.SYNOPSIS
    Launch TF2 with this HUD installed and assert it reaches the main menu without crashing.

.DESCRIPTION
    The one defect class no static check catches. On 2026-08-19 a HUD change crashed TF2 at the
    main menu; every structural check on the repo passed, because they all prove a panel parses,
    never that the client survives building it.

    THE ORACLE IS A CRASH DUMP, NOT AN EXIT CODE.

    Steam writes crash_tf_win64.exe_<stamp>_N.dmp into its dumps directory when the client dies.
    That file is the measurement: it exists only when TF2 actually crashed, it is written by
    Steam rather than by this script, and it cannot be faked by a mis-parsed log line. An exit
    code is useless here because this script kills the process itself to end the test, and
    console.log is unreliable because a crash truncates it mid-flush.

    SYNCHRONISATION IS ON A CONDITION, NEVER ON A CLOCK.

    The script waits for a marker echoed by TF2 itself into console.log (-condebug), which proves
    the client got as far as executing launch commands. It then holds until the settle deadline,
    watching for the process to die. The deadline is a deadline, not a sleep: the loop exits the
    instant the process exits, and a healthy run is cut short only by the clock because "nothing
    went wrong" has no positive event to wait for.

    WHY THE SETTLE PERIOD IS NOT OPTIONAL.

    The marker alone is insufficient and this was measured, not assumed. In the 2026-08-19 crash
    the client got far enough to run autoexec.cfg and print its banner before dying, so a test
    that stopped at the marker would have PASSED on the exact crash it exists to catch. Both
    conditions are required: marker reached AND still alive afterwards AND no new dump.

.PARAMETER SettleSeconds
    How long the main menu must survive after the marker. Default 25. The observed crash landed
    inside ~5s of the banner, so this has ample margin; raise it if a slower failure is suspected.

.PARAMETER LaunchTimeoutSeconds
    Deadline for the marker to appear at all. Default 180. Exceeding it fails the run rather than
    passing it -- a client that never reaches the menu is a failure, not an inconclusive result.

.PARAMETER KeepOpen
    Leave TF2 running at the end instead of closing it. For looking at the HUD by hand after a
    pass.

.NOTES
    TAKES THE MACHINE-WIDE DESKTOP LOCK. Run it through run-exclusive.ps1:

        ..\..\run-exclusive.ps1 pwsh ./tests/Invoke-HudSmokeTest.ps1

    Launching a game steals the foreground exactly like a UI suite does, and per the house rules
    it must not land on top of another agent's run or a person's manual check.
#>
[CmdletBinding()]
param(
    [int]$SettleSeconds = 25,
    [int]$LaunchTimeoutSeconds = 180,
    [switch]$KeepOpen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$tf        = 'F:\SteamLibrary\steamapps\common\Team Fortress 2'
$exe       = Join-Path $tf 'tf_win64.exe'
$consoleLog = Join-Path $tf 'tf\console.log'
$dumpDir   = 'C:\Program Files (x86)\Steam\dumps'
$marker    = "HUDSMOKE_$([guid]::NewGuid().ToString('N').Substring(0,12))"

function Fail([string]$m) { Write-Host "FAIL  $m" -ForegroundColor Red; exit 1 }
function Pass([string]$m) { Write-Host "PASS  $m" -ForegroundColor Green; exit 0 }
function Info([string]$m) { Write-Host "      $m" -ForegroundColor DarkGray }

if (-not (Test-Path $exe)) { Fail "TF2 not found at $exe" }
if (Get-Process -Name 'tf_win64' -ErrorAction SilentlyContinue) {
    Fail 'TF2 is already running. Close it first -- this test needs to own the client.'
}

# Which HUD is actually installed? A pass means nothing if the junction points elsewhere.
$installed = Join-Path $tf 'tf\custom\Garm3n-VIP-Quad'
if (-not (Test-Path $installed)) { Fail "HUD not installed at $installed" }
$head = (git rev-parse --short HEAD 2>$null)
$dirty = (git status --porcelain 2>$null | Measure-Object).Count
Info "HUD under test: $head$(if ($dirty) { " +$dirty uncommitted" })"

# Baseline the oracle BEFORE launching, so only dumps from this run count.
$dumpsBefore = @()
if (Test-Path $dumpDir) {
    $dumpsBefore = @(Get-ChildItem $dumpDir -Filter 'crash_tf_win64*.dmp' -ErrorAction SilentlyContinue |
                     Select-Object -ExpandProperty Name)
}
Info "existing tf_win64 dumps: $($dumpsBefore.Count)"

# console.log is append-mode under -condebug, so record the length and only read past it.
$logOffset = if (Test-Path $consoleLog) { (Get-Item $consoleLog).Length } else { 0 }

Info "launching, marker $marker"
$proc = Start-Process -FilePath $exe -PassThru -ArgumentList @(
    '-steam', '-game', 'tf', '-condebug', '-novid', '-windowed', '-w', '1280', '-h', '720',
    '+echo', $marker
)

function Get-NewLog {
    if (-not (Test-Path $consoleLog)) { return '' }
    $fs = [System.IO.File]::Open($consoleLog, 'Open', 'Read', 'ReadWrite')
    try {
        if ($fs.Length -le $logOffset) { return '' }
        $fs.Seek($logOffset, 'Begin') | Out-Null
        $buf = New-Object byte[] ($fs.Length - $logOffset)
        [void]$fs.Read($buf, 0, $buf.Length)
        return [System.Text.Encoding]::ASCII.GetString($buf)
    } finally { $fs.Dispose() }
}

function Stop-Tf2 {
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
}

function Get-NewDumps {
    if (-not (Test-Path $dumpDir)) { return @() }
    @(Get-ChildItem $dumpDir -Filter 'crash_tf_win64*.dmp' -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -notin $dumpsBefore } | Select-Object -ExpandProperty Name)
}

# --- Condition 1: reach the marker, i.e. the client executed launch commands -----------------
$deadline = (Get-Date).AddSeconds($LaunchTimeoutSeconds)
$reached  = $false
while ((Get-Date) -lt $deadline) {
    if ($proc.HasExited) {
        $d = Get-NewDumps
        Fail "TF2 exited during startup, before reaching the menu. New dumps: $($d.Count) $($d -join ', ')"
    }
    if ((Get-NewLog) -match [regex]::Escape($marker)) { $reached = $true; break }
    Start-Sleep -Milliseconds 500
}
if (-not $reached) {
    Stop-Tf2
    Fail "marker never appeared within ${LaunchTimeoutSeconds}s -- client never reached the menu"
}
Info 'marker reached; menu commands executed'

# --- Condition 2: survive the settle period ---------------------------------------------------
# Required. The 2026-08-19 crash printed its autoexec banner and died afterwards, so stopping at
# condition 1 would have passed on the very defect this test exists to catch.
$settleEnd = (Get-Date).AddSeconds($SettleSeconds)
while ((Get-Date) -lt $settleEnd) {
    if ($proc.HasExited) {
        $d = Get-NewDumps
        Fail "TF2 died $([int]((Get-Date) - $settleEnd).TotalSeconds + $SettleSeconds)s after reaching the menu. New dumps: $($d.Count) $($d -join ', ')"
    }
    Start-Sleep -Milliseconds 500
}

# --- Condition 3: the oracle ------------------------------------------------------------------
$newDumps = Get-NewDumps
if ($newDumps.Count -gt 0) {
    Stop-Tf2
    Fail "Steam wrote $($newDumps.Count) new crash dump(s) even though the process survived: $($newDumps -join ', ')"
}

if ($KeepOpen) {
    Info 'leaving TF2 open (-KeepOpen)'
} else {
    Stop-Tf2
}
Pass "reached the main menu and held it for ${SettleSeconds}s with no crash dump  [$head]"

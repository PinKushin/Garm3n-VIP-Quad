<#
.SYNOPSIS
    Report where this HUD has fallen behind the shipped game. Read-only; modifies nothing.

.DESCRIPTION
    A custom .res file is a full REPLACEMENT, not an overlay. So every panel Valve adds to a file
    this HUD overrides is simply absent here, silently, with no error anywhere. That is how this
    HUD lost twelve main-menu panels, ten ClientScheme fonts and the scoreboard's Damage/Support
    readout over eight years.

    The oracle is the game itself: the stock HUD extracted from tf2_misc_dir.vpk. Not the upstream
    repository, which is dead and by definition agrees with us. The thing that moved is TF2.

    Checks run:
      1. rot        panels stock defines that our override of the same file does not
      2. scheme     font/color/border names our files reference that our ClientScheme lacks
      3. loc        #Tokens our files reference that are not in tf_english.txt
      4. structure  files that do not parse or have unbalanced braces

    IT REPORTS A DELTA, NOT ABSOLUTE GAPS, and that is what makes it usable.

    Run absolutely, it finds 275 gaps, and nearly all are this HUD deliberately deleting stock
    decoration in 2017 -- every titlelabeldropshadow, divider, mainbackground and numberbg Garm3n
    stripped on purpose. From a single snapshot "Valve added this" and "the author removed this"
    are indistinguishable: both are a block in stock that is not here.

    Change over time IS distinguishable. A gap that appears where none existed at the last check
    is Valve adding surface. So tests/rot-snapshot.txt records the known gap set, and a run
    reports only what is new since. A tool that cries 275 times is a tool nobody reads.

.PARAMETER Refresh
    Re-extract the stock HUD even if the cache exists. Do this after a TF2 update -- that is the
    whole point of the tool.

.PARAMETER ShowAccepted
    Also list the gaps that were already present at the last snapshot.

.PARAMETER UpdateSnapshot
    Record the current gap set as the new baseline. Do this only after reviewing the delta --
    regenerating blindly launders new rot into the accepted set.

.NOTES
    Does NOT need the desktop lock. It never launches the game and only reads files.
#>
[CmdletBinding()]
param(
    [switch]$Refresh,
    [switch]$ShowAccepted,
    [switch]$UpdateSnapshot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib\KeyValues.ps1')

$repo     = Split-Path $PSScriptRoot -Parent
$tf       = 'F:\SteamLibrary\steamapps\common\Team Fortress 2'
$vpk      = Join-Path $tf 'bin\x64\vpk.exe'
$misc     = Join-Path $tf 'tf\tf2_misc_dir.vpk'
$english  = Join-Path $tf 'tf\resource\tf_english.txt'

# Stock lives OUTSIDE the repo on purpose. It is ~1000 extracted game files; a gitignored folder
# in the working tree is one `git add -A` away from being committed forever.
$stockRoot = Join-Path $env:LOCALAPPDATA 'Garm3n-HudRot\stock'

function Info($m) { Write-Host "      $m" -ForegroundColor DarkGray }
function Head($m) { Write-Host "`n$m" -ForegroundColor Cyan }

# ---------------------------------------------------------------------------------------------
# Stock extraction
# ---------------------------------------------------------------------------------------------
function Update-StockHud {
    if (-not (Test-Path $vpk))  { throw "vpk.exe not found at $vpk" }
    if (-not (Test-Path $misc)) { throw "tf2_misc_dir.vpk not found at $misc" }

    if (Test-Path $stockRoot) { Remove-Item $stockRoot -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $stockRoot | Out-Null

    $entries = & $vpk l $misc 2>$null |
               ForEach-Object { $_ -replace "`r", '' } |
               Where-Object { $_ -match '^(resource|scripts)/' }

    # vpk.exe will NOT create directories. It fails with "Unable to create <path>" and still
    # prints "extracting <path>", so a missing tree looks like a successful run producing nothing.
    $entries | ForEach-Object { Split-Path $_ -Parent } | Sort-Object -Unique | ForEach-Object {
        if ($_) { New-Item -ItemType Directory -Force -Path (Join-Path $stockRoot $_) | Out-Null }
    }

    Push-Location $stockRoot
    try {
        for ($i = 0; $i -lt $entries.Count; $i += 40) {
            $batch = $entries[$i..([Math]::Min($i + 39, $entries.Count - 1))]
            & $vpk x $misc @batch *>$null
        }
    } finally { Pop-Location }

    $got = @(Get-ChildItem $stockRoot -Recurse -File).Count
    if ($got -lt ($entries.Count * 0.9)) {
        throw "extraction produced $got files from $($entries.Count) entries -- refusing to run on a partial oracle"
    }
    Info "extracted $got stock files"
}

if ($Refresh -or -not (Test-Path $stockRoot)) {
    Info 'extracting stock HUD from tf2_misc_dir.vpk ...'
    Update-StockHud
} else {
    Info "stock cache: $stockRoot (use -Refresh after a TF2 update)"
}

# ---------------------------------------------------------------------------------------------
# Baseline
# ---------------------------------------------------------------------------------------------
# The tool reports a DELTA against a snapshot, not absolute gaps, and that distinction is the
# difference between it being used and being ignored.
#
# An absolute run reports 275 findings, and almost all of them are this HUD deliberately deleting
# stock decoration -- every titlelabeldropshadow, divider, mainbackground and numberbg that
# Garm3n stripped on purpose in 2017. From one snapshot there is no way to tell "Valve added
# this" from "the author removed this", because both look identical: a block in stock that is not
# here.
#
# What IS distinguishable is change over time. A gap that appears after a TF2 update, where none
# existed at the last check, is Valve adding surface -- which is exactly the rot this exists to
# find. So: snapshot the current gaps, then report only what is new.
$snapshotPath = Join-Path $PSScriptRoot 'rot-snapshot.txt'
$snapshot = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
if (Test-Path $snapshotPath) {
    foreach ($line in [System.IO.File]::ReadAllLines($snapshotPath)) {
        $l = $line.Trim()
        if ($l -and -not $l.StartsWith('#')) { [void]$snapshot.Add($l) }
    }
}

$findings = [System.Collections.Generic.List[object]]::new()
$accepted = [System.Collections.Generic.List[object]]::new()
$allGaps  = [System.Collections.Generic.List[string]]::new()
function Add-Finding($check, $key, $detail) {
    $id = "$check|$key"
    $allGaps.Add($id)
    if ($snapshot.Contains($id)) { $accepted.Add([pscustomobject]@{ Check=$check; Key=$key; Why='present at last snapshot' }) }
    else { $findings.Add([pscustomobject]@{ Check=$check; Key=$key; Detail=$detail }) }
}

# ---------------------------------------------------------------------------------------------
# 4. structure  (run first: nothing downstream is trustworthy if a file does not parse)
# ---------------------------------------------------------------------------------------------
$hudFiles = Get-ChildItem $repo -Recurse -File -Include '*.res','*.txt' |
            Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\tests\\' -and $_.FullName -notmatch '\\docs\\' }

foreach ($f in $hudFiles) {
    $bad = Test-KvBraceBalance $f.FullName
    if ($bad) {
        $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
        Add-Finding 'structure' $rel $bad
    }
}

# ---------------------------------------------------------------------------------------------
# 1. rot  -- panels stock defines that our override of the same file lacks
# ---------------------------------------------------------------------------------------------
foreach ($f in $hudFiles) {
    $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
    $stockPath = Join-Path $stockRoot $rel
    if (-not (Test-Path $stockPath)) { continue }   # our own file, nothing to compare against

    try {
        $ours  = Get-KvPaths (Get-KvBody (Read-KvFile $f.FullName))
        $stock = Get-KvPaths (Get-KvBody (Read-KvFile $stockPath))
    } catch { Add-Finding 'structure' $rel "parse failed: $($_.Exception.Message)"; continue }

    # Only report BLOCKS. A missing leaf key usually means "we restyled it"; a missing block means
    # a whole panel Valve added is absent, which is the actual rot.
    $missingBlocks = @($stock | Where-Object {
        $p = $_
        -not $ours.Contains($p) -and ($stock | Where-Object { $_.StartsWith("$p.") } | Select-Object -First 1)
    })
    foreach ($m in $missingBlocks) { Add-Finding 'rot' "${rel}:${m}" 'panel present in stock, absent here' }
}

# ---------------------------------------------------------------------------------------------
# 2. scheme  -- names our files reference that our own ClientScheme does not define
# ---------------------------------------------------------------------------------------------
$schemePath = Join-Path $repo 'resource\ClientScheme.res'
if (Test-Path $schemePath) {
    $scheme = Read-KvFile $schemePath
    $sc = if ($scheme.Contains('scheme')) { $scheme['scheme'] } else { [ordered]@{} }
    $defined = @{}
    foreach ($section in 'fonts','colors','borders') {
        if ($sc.Contains($section)) { foreach ($k in $sc[$section].Keys) { $defined[$k] = $section } }
    }
    # Colors may also be referenced by literal "R G B A", which is always valid.
    foreach ($f in $hudFiles) {
        if ($f.FullName -eq $schemePath) { continue }
        $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
        $text = [System.IO.File]::ReadAllText($f.FullName)
        foreach ($m in [regex]::Matches($text, '"(font|fgcolor|bgcolor|fillcolor|border|fgcolor_override|bgcolor_override)"\s+"([^"\n]+)"', 'IgnoreCase')) {
            $val = $m.Groups[2].Value.Trim()
            if ($val -match '^\d+\s+\d+\s+\d+(\s+\d+)?$') { continue }   # literal colour
            if ($val -eq '' -or $val -eq '0' -or $val -eq '1') { continue }
            if (-not $defined.ContainsKey($val.ToLowerInvariant())) {
                Add-Finding 'scheme' $val "referenced by $rel, not defined in ClientScheme.res"
            }
        }
    }
}

# ---------------------------------------------------------------------------------------------
# 3. loc  -- #Tokens that do not exist in tf_english.txt
# ---------------------------------------------------------------------------------------------
# Tokens are NOT all in tf_english.txt. #GameUI_* live in hl2/resource/gameui_english.txt, and
# checking only TF's file reports them as dangling -- the same wrong-instrument mistake that made
# a quote-anchored grep declare a present border missing. Load every localization file the client
# does.
$locFiles = @(
    (Join-Path $tf 'tf\resource'),
    (Join-Path $tf 'hl2\resource'),
    (Join-Path $tf 'platform\resource')
) | Where-Object { Test-Path $_ } | ForEach-Object {
    Get-ChildItem $_ -Filter '*_english.txt' -File -ErrorAction SilentlyContinue
}

if ($locFiles.Count -gt 0) {
    $known = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($lf in $locFiles) {
        # These ship as UTF-16LE. Read as ASCII and every token silently vanishes.
        $locText = [System.IO.File]::ReadAllText($lf.FullName, [System.Text.Encoding]::Unicode)
        foreach ($m in [regex]::Matches($locText, '"([A-Za-z0-9_]+)"\s+"')) { [void]$known.Add($m.Groups[1].Value) }
    }
    Info "localization: $($known.Count) tokens from $($locFiles.Count) file(s)"
    foreach ($f in $hudFiles) {
        $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
        $text = [System.IO.File]::ReadAllText($f.FullName)
        foreach ($m in [regex]::Matches($text, '"labelText"\s+"#([A-Za-z0-9_]+)"', 'IgnoreCase')) {
            $tok = $m.Groups[1].Value
            if (-not $known.Contains($tok)) { Add-Finding 'loc' "#$tok" "referenced by $rel, not in tf_english.txt" }
        }
    }
}

# ---------------------------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------------------------
$order = 'structure','rot','scheme','loc'
$labels = @{
    structure = 'STRUCTURE  file does not parse'
    rot       = 'ROT        stock has a panel this HUD does not'
    scheme    = 'SCHEME     name referenced but never defined'
    loc       = 'LOC        localization token does not exist'
}

foreach ($c in $order) {
    $items = @($findings | Where-Object Check -eq $c)
    if ($items.Count -eq 0) { continue }
    Head "$($labels[$c])  ($($items.Count))"
    foreach ($i in $items) { Write-Host ("  {0}`n      {1}" -f $i.Key, $i.Detail) }
}

if ($ShowAccepted -and $accepted.Count -gt 0) {
    Head "ACCEPTED (baselined, not failures)  ($($accepted.Count))"
    foreach ($a in $accepted) { Write-Host ("  [{0}] {1}`n      {2}" -f $a.Check, $a.Key, $a.Why) -ForegroundColor DarkGray }
}

Write-Host ''

if ($UpdateSnapshot) {
    $header = @(
        '# Snapshot of every gap between this HUD and the shipped stock HUD.',
        '#',
        '# Regenerate with:  pwsh ./tests/Invoke-HudRotCheck.ps1 -Refresh -UpdateSnapshot',
        '# Do that ONLY after reviewing the delta -- regenerating blindly launders new rot into',
        '# the accepted set, which is the one way this tool can be made useless.',
        '#',
        "# Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') against TF2 build $(if (Test-Path (Join-Path $tf '..\..\appmanifest_440.acf')) { (Select-String -Path (Join-Path $tf '..\..\appmanifest_440.acf') -Pattern '"buildid"\s+"(\d+)"').Matches.Groups[1].Value } else { 'unknown' })",
        "# $($allGaps.Count) entries",
        ''
    )
    # Join with "`n" rather than WriteAllLines, which emits CRLF on Windows and trips the
    # "CRLF will be replaced by LF" warning that .gitattributes eol=lf exists to remove.
    $lines = $header + ($allGaps | Sort-Object -Unique)
    [System.IO.File]::WriteAllText($snapshotPath, (($lines -join "`n") + "`n"))
    Write-Host "SNAPSHOT  wrote $($allGaps.Count) entries to tests/rot-snapshot.txt" -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path $snapshotPath)) {
    Write-Host "NO SNAPSHOT  $($allGaps.Count) gap(s) found, none can be judged new." -ForegroundColor Yellow
    Write-Host '      Review them, then run with -UpdateSnapshot to record the current state as the' -ForegroundColor DarkGray
    Write-Host '      baseline. After that, this reports only what a TF2 update adds.' -ForegroundColor DarkGray
    exit 2
}

if ($findings.Count -eq 0) {
    Write-Host "PASS  nothing new since the last snapshot. $($accepted.Count) known gap(s)." -ForegroundColor Green
    exit 0
}
Write-Host "FAIL  $($findings.Count) NEW gap(s) since the snapshot; $($accepted.Count) known." -ForegroundColor Red
Write-Host '      These appeared after the snapshot was taken -- most likely a TF2 update adding' -ForegroundColor DarkGray
Write-Host '      surface this HUD now silently lacks. Patch them, then -UpdateSnapshot.' -ForegroundColor DarkGray
exit 1

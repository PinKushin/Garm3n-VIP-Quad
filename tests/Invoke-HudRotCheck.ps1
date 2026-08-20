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
      1b. missingfile  a whole file every reference HUD ships that neither stock nor we do.
                    The rot check compares panels WITHIN files present in both trees and is
                    blind to a file absent entirely -- which is how
                    HudItemEffectMeter_Action.res spammed the console for years.
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

# ---------------------------------------------------------------------------------------------
# Reference HUDs -- the control group
# ---------------------------------------------------------------------------------------------
# A gap on its own is ambiguous: "Valve added this panel" and "Garm3n deleted this panel" both
# look like a block in stock that is absent here. One subject cannot separate them.
#
# Three actively maintained HUDs can. If rayshud, flawhud and budhud all carry a panel this HUD
# lacks, Garm3n is the outlier and it is probably rot. If they all drop it too, it is something
# HUD authors routinely strip and almost certainly design.
#
# This is not hypothetical -- scoring the existing snapshot this way contradicted my own
# recommendations. HudStopWatch.res scored 0/3 (every maintained HUD drops all 8 of its gaps) and
# ScoreBoard.res scored 0/3 on every entry, yet I had put both forward as work. HudTournament.res
# scored 30/30 at 3-of-3, which is the one that is genuinely behind.
#
# Populate with resource/ and scripts/ .res and .txt from each HUD, under refhuds/<name>/.
# Absent entirely, everything still works and the column is simply omitted.
# TWO corpora, answering two different questions.
#
#   refhuds/  rayshud, flawhud, budhud -- other authors, actively maintained.
#             "Do modern HUDs carry this?" Conflates what TF2 needs with what a
#             given designer chooses to style.
#
#   sibhuds/  Garm3n's own other HUDs, 18 of them from TF2HUDsArchive.
#             "Does GARM3N carry this?" Controls for taste, because it is the same
#             designer, so a difference means something about THIS HUD rather than
#             about aesthetics.
#
# The second is the sharper instrument and it overturned a call the first produced.
# HudStopWatch.res scored 0-of-3 against the maintained HUDs -- every one drops all
# eight of its gaps -- so it was written off as design. Garm3n's own HUDs carry all
# eight. Quad is the outlier among its author's own work, which is the opposite
# reading, and only the same-author corpus can see it.
function New-HudIndex {
    param([Parameter(Mandatory)][string]$Root)
    $out = @{}
    if (-not (Test-Path $Root)) { return $out }
    foreach ($hud in (Get-ChildItem $Root -Directory)) {
        $idx = @{}
        foreach ($f in (Get-ChildItem $hud.FullName -Recurse -File -Include '*.res')) {
            $key = $f.Name.ToLowerInvariant()
            if (-not $idx.ContainsKey($key)) {
                $idx[$key] = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            }
            foreach ($w in [regex]::Matches([System.IO.File]::ReadAllText($f.FullName), '[A-Za-z0-9_]+')) {
                [void]$idx[$key].Add($w.Value)
            }
        }
        $out[$hud.Name] = $idx
    }
    return $out
}

$refRoot  = Join-Path $env:LOCALAPPDATA 'Garm3n-HudRot\refhuds'
$sibRoot  = Join-Path $env:LOCALAPPDATA 'Garm3n-HudRot\sibhuds'
$refIndex = New-HudIndex $refRoot
$sibIndex = New-HudIndex $sibRoot
if ($refIndex.Count) { Info "other-author HUDs: $($refIndex.Keys -join ', ')" }
else { Info "no reference HUDs at $refRoot -- that column disabled" }
if ($sibIndex.Count) { Info "same-author HUDs: $($sibIndex.Count) of Garm3n's own" }
else { Info "no sibling HUDs at $sibRoot -- that column disabled" }

function Get-CorpusScore {
    <#  How many HUDs in a corpus define this panel in their copy of the same file.
        Matches the leaf name inside the same-named .res anywhere in that HUD's tree, which is
        deliberately loose: budhud splits one stock file across many, so an exact path match
        would report false absences.  #>
    param([hashtable]$Index, [string]$RelFile, [string]$PanelPath)
    if ($Index.Count -eq 0) { return $null }
    $base = [System.IO.Path]::GetFileName($RelFile).ToLowerInvariant()
    $parts = $PanelPath -split '\.'
    $leaf = $parts[-1]
    # A conditional block's leaf is the CONDITION, not a panel: "hudstopwatchbg.if_comp" ends in
    # "if_comp", which no HUD contains as a control name. Scoring that matched nothing and
    # silently zeroed every conditional gap -- HudStopWatch.res dropped out of the report
    # entirely while all 18 sibling HUDs demonstrably carry its panels. Step back to the panel
    # the condition modifies.
    if ($leaf -match '^if_' -and $parts.Count -ge 2) { $leaf = $parts[-2] }
    $n = 0
    foreach ($hud in $Index.Keys) {
        $idx = $Index[$hud]
        if ($idx.ContainsKey($base) -and $idx[$base].Contains($leaf)) { $n++ }
    }
    return $n
}

function Get-RefScore { param([string]$RelFile, [string]$PanelPath)
    Get-CorpusScore $refIndex $RelFile $PanelPath }
function Get-SibScore { param([string]$RelFile, [string]$PanelPath)
    Get-CorpusScore $sibIndex $RelFile $PanelPath }

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
    foreach ($m in $missingBlocks) {
        $score = Get-RefScore $rel $m
        $detail = if ($null -eq $score) {
            'panel present in stock, absent here'
        } else {
            $verdict = switch ($score) {
                3       { 'ALL 3 reference HUDs carry it -- this HUD is the outlier, likely rot' }
                2       { '2 of 3 reference HUDs carry it' }
                1       { '1 of 3 reference HUDs carries it' }
                default { 'NO reference HUD carries it -- routinely stripped, likely design' }
            }
            "stock has it, we do not. $verdict"
        }
        Add-Finding 'rot' "${rel}:${m}" $detail
    }
}

# ---------------------------------------------------------------------------------------------
# 1b. missingfile  -- a file every reference HUD ships that NOBODY here provides
# ---------------------------------------------------------------------------------------------
# The rot check above compares panels WITHIN files present in both trees, so it is structurally
# blind to a file that is absent entirely. That blindness cost a real defect:
# HudItemEffectMeter_Action.res existed in neither stock nor this HUD, and TF2 asked for it on
# every spawn, printing "Failed to load" 26 times a session for years.
#
# The signal is narrow on purpose. A stock file we simply do not override is NOT a finding --
# TF2 falls back to stock and everything works, and that describes most of the stock tree. What
# matters is a file the maintained HUDs all ship which stock does NOT, because that means Valve
# asks for something it never shipped and HUD authors fill the gap by hand.
#
# Requiring all three reference HUDs filters their own private files: budhud's bh_* helpers and
# rayshud's customization variants are unique to them and never score 3.
if ($refIndex.Count -ge 2) {
    $stockNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($f in (Get-ChildItem $stockRoot -Recurse -File -Filter '*.res')) { [void]$stockNames.Add($f.Name) }

    # The extracted cache is tf2_misc only, but the client also loads UI from hl2 and platform --
    # ConfirmDialog.res, MainPanel.res and MessageBoxDialog.res all live in hl2_misc_dir.vpk.
    # Listing those VPKs (names only, no extraction) stops them reporting as missing. Found the
    # hard way: all three showed up as false positives on this check's first run.
    foreach ($extra in @('hl2\hl2_misc_dir.vpk', 'platform\platform_misc_dir.vpk')) {
        $vp = Join-Path $tf $extra
        if (-not (Test-Path $vp)) { continue }
        foreach ($line in (& $vpk l $vp 2>$null)) {
            $l = ($line -replace "`r", '').Trim()
            if ($l -match '\.res$') { [void]$stockNames.Add([System.IO.Path]::GetFileName($l)) }
        }
    }

    # HUD-authoring conventions the GAME never requests. rayshud, flawhud and budhud all split
    # ClientScheme into #base'd parts, so clientscheme_colors.res and clientscheme_borders.res
    # score 3-of-3 while existing nowhere in TF2. Garm3n keeps one monolithic ClientScheme, which
    # is a valid choice, not a missing file.
    $conventionOnly = '^clientscheme_'
    $ourNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($f in $hudFiles) { [void]$ourNames.Add($f.Name) }

    $counts = @{}
    foreach ($hud in $refIndex.Keys) {
        foreach ($n in $refIndex[$hud].Keys) {
            if (-not $counts.ContainsKey($n)) { $counts[$n] = 0 }
            $counts[$n]++
        }
    }
    $need = $refIndex.Count      # all of them
    foreach ($n in ($counts.Keys | Sort-Object)) {
        if ($counts[$n] -lt $need) { continue }
        if ($n -match $conventionOnly) { continue }  # HUD convention, not a game request
        if ($stockNames.Contains($n)) { continue }   # stock provides it; not our problem
        if ($ourNames.Contains($n))   { continue }   # we already have it
        Add-Finding 'missingfile' $n `
            "every reference HUD ships this and neither stock nor we do -- TF2 has nothing to load"
    }
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
$order = 'structure','missingfile','rot','scheme','loc'
$labels = @{
    structure = 'STRUCTURE  file does not parse'
    missingfile = 'MISSINGFILE  a file every reference HUD ships and nobody here provides'
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

# Corroboration summary over the KNOWN gaps. The snapshot deliberately says nothing about whether
# a gap is design or rot; this does, using three independent HUDs as bystanders.
if ($refIndex.Count -gt 0 -and $accepted.Count -gt 0) {
    $scored    = @{}
    $sibScored = @{}     # [0] = no sibling has it, [1] = ALL siblings have it
    foreach ($a in ($accepted | Where-Object Check -eq 'rot')) {
        $i = $a.Key.IndexOf(':')
        if ($i -lt 0) { continue }
        $f     = $a.Key.Substring(0, $i)
        $panel = $a.Key.Substring($i + 1)
        $s = Get-RefScore $f $panel
        if ($null -ne $s) {
            if (-not $scored.ContainsKey($f)) { $scored[$f] = @(0,0,0,0) }
            $scored[$f][$s]++
        }
        $sv = Get-SibScore $f $panel
        if ($null -ne $sv) {
            if (-not $sibScored.ContainsKey($f)) { $sibScored[$f] = @(0,0) }
            # "all" is deliberately a majority rather than unanimity: the 18 siblings span years
            # and several are stripped-down variants, so requiring every one would report nothing.
            if ($sv -ge [int]($sibIndex.Count * 0.6)) { $sibScored[$f][1]++ } else { $sibScored[$f][0]++ }
        }
    }
    if ($scored.Count -gt 0) {
        Head 'KNOWN GAPS, scored against two corpora'
        Write-Host ('  {0,-38} {1,11}   {2,15}' -f '', 'other authors', "Garm3n's own") -ForegroundColor DarkGray
        Write-Host ('  {0,-38} {1,5} {2,5}   {3,7} {4,7}' -f 'file','all','none','all','none') -ForegroundColor DarkGray
        foreach ($f in ($scored.Keys | Sort-Object { -$sibScored[$_][1] })) {
            $c = $scored[$f]
            $s = if ($sibScored.ContainsKey($f)) { $sibScored[$f] } else { @(0,0) }
            if ($c[3] -eq 0 -and $c[2] -eq 0 -and $s[1] -eq 0) { continue }
            Write-Host ('  {0,-38} {1,5} {2,5}   {3,7} {4,7}' -f `
                ([System.IO.Path]::GetFileName($f)), $c[3], $c[0], $s[1], $s[0])
        }
        Write-Host "      Garm3n's own is the sharper column: same designer, so a difference is about" -ForegroundColor DarkGray
        Write-Host '      THIS HUD rather than about taste. Where the two disagree, trust that one.' -ForegroundColor DarkGray
    }
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

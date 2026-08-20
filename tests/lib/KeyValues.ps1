<#
    A real KeyValues/VDF parser, because a regex is not one.

    On 2026-08-19 two separate findings in this repo were wrong because they were produced by
    grep. Both times the pattern was quote-anchored and the key it was looking for is written
    WITHOUT quotes in the file:

        MainMenuBGBorder                 <- ClientScheme.res line 6158, no quotes
        GameUIButtonsSteamController     <- stock ClientScheme.res, no quotes

    grep -c '"MainMenuBGBorder"' returns 0 on a file that plainly defines it. That produced a
    confident "MISSING" for a border that was present, and sent a crash investigation down a dead
    end. A tokenizer cannot make that mistake, which is the entire reason this file exists.

    Handles: quoted and unquoted keys and values, // comments (quote-aware), platform and HUD
    conditionals in [brackets], #base directives, and duplicate keys (merged, later wins, which
    is how VGUI applies a block twice).

    Deliberately NOT handled: escape sequences inside quoted strings. VDF's are barely specified
    and no HUD file here uses one. If that changes this will need revisiting rather than guessing.
#>

Set-StrictMode -Version Latest

function Remove-KvComments {
    <#  Strips // to end of line, but only outside quotes. A blind -replace '//.*' would eat
        half of any value containing a double slash. #>
    param([string]$Line)
    $inQuote = $false
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $c = $Line[$i]
        if ($c -eq '"') { $inQuote = -not $inQuote; continue }
        if (-not $inQuote -and $c -eq '/' -and $i + 1 -lt $Line.Length -and $Line[$i + 1] -eq '/') {
            return $Line.Substring(0, $i)
        }
    }
    return $Line
}

function Get-KvTokens {
    param([string]$Text)
    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($line in ($Text -split "`n")) {
        $clean = Remove-KvComments ($line -replace "`r", '')
        foreach ($m in [regex]::Matches($clean, '"([^"]*)"|(\{)|(\})|(\[[^\]]*\])|([^\s{}"\[\]]+)')) {
            if     ($m.Groups[1].Success) { $out.Add(@{ Kind = 'str';  Text = $m.Groups[1].Value }) }
            elseif ($m.Groups[2].Success) { $out.Add(@{ Kind = 'open'; Text = '{' }) }
            elseif ($m.Groups[3].Success) { $out.Add(@{ Kind = 'close';Text = '}' }) }
            elseif ($m.Groups[4].Success) { $out.Add(@{ Kind = 'cond'; Text = $m.Groups[4].Value }) }
            else                          { $out.Add(@{ Kind = 'str';  Text = $m.Groups[5].Value }) }
        }
    }
    return $out
}

function ConvertFrom-KeyValues {
    <#  Returns a nested ordered hashtable. Leaf values are strings; blocks are hashtables.
        Conditionals are dropped: this tool asks "is this key present at all", and a key that
        exists only under [$WIN32] is still present.  #>
    param([string]$Text)

    $tokens = Get-KvTokens $Text
    $root   = [ordered]@{}
    $stack  = [System.Collections.Generic.List[object]]::new()
    $stack.Add($root)
    $pending = $null
    $i = 0

    while ($i -lt $tokens.Count) {
        $t = $tokens[$i]
        switch ($t.Kind) {
            'cond'  { $i++; continue }
            'open'  {
                $cur = $stack[$stack.Count - 1]
                $name = if ($null -ne $pending) { $pending } else { '' }
                $key = $name.ToLowerInvariant()
                if (-not $cur.Contains($key) -or $cur[$key] -isnot [System.Collections.IDictionary]) {
                    $cur[$key] = [ordered]@{}
                }
                $stack.Add($cur[$key])
                $pending = $null
                $i++
            }
            'close' {
                if ($stack.Count -gt 1) { $stack.RemoveAt($stack.Count - 1) }
                $pending = $null
                $i++
            }
            'str'   {
                # Look ahead past conditionals for the real next token.
                $j = $i + 1
                while ($j -lt $tokens.Count -and $tokens[$j].Kind -eq 'cond') { $j++ }
                $next = if ($j -lt $tokens.Count) { $tokens[$j] } else { $null }

                if ($null -ne $next -and $next.Kind -eq 'open') {
                    $pending = $t.Text
                    $i = $j
                } elseif ($null -ne $next -and $next.Kind -eq 'str') {
                    $cur = $stack[$stack.Count - 1]
                    $cur[$t.Text.ToLowerInvariant()] = $next.Text
                    $i = $j + 1
                } else {
                    $i++
                }
            }
            default { $i++ }
        }
    }
    return $root
}

function Get-KvPaths {
    <#  Flattens to dotted lowercase paths. Blocks and leaves both appear, so a caller can tell
        "this panel is missing entirely" from "this panel exists but lost a key".  #>
    param(
        [Parameter(Mandatory)] $Node,
        [string]$Prefix = '',
        [System.Collections.Generic.HashSet[string]]$Acc = $null
    )
    if ($null -eq $Acc) { $Acc = [System.Collections.Generic.HashSet[string]]::new() }
    foreach ($k in $Node.Keys) {
        $path = if ($Prefix) { "$Prefix.$k" } else { $k }
        [void]$Acc.Add($path)
        if ($Node[$k] -is [System.Collections.IDictionary]) {
            Get-KvPaths -Node $Node[$k] -Prefix $path -Acc $Acc | Out-Null
        }
    }
    return $Acc
}

function Get-KvBody {
    <#  A .res file's outermost block is named after the file itself -- "Resource/UI/Foo.res".
        Comparing two files including that name reports a missing panel whenever the names differ,
        which happens constantly because HUD authors copy a file and leave the old header. Strip
        the wrapper so the comparison is about contents.

        Only strips when there is exactly one top-level block; a file with several real top-level
        entries is passed through untouched.  #>
    param([Parameter(Mandatory)]$Node)
    if ($Node.Keys.Count -eq 1) {
        $only = @($Node.Keys)[0]
        if ($Node[$only] -is [System.Collections.IDictionary]) { return $Node[$only] }
    }
    return $Node
}

function Read-KvFile {
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    # HUD files are ASCII or UTF-8; tf_english.txt is UTF-16 and is read elsewhere.
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    return ConvertFrom-KeyValues $text
}

function Test-KvBraceBalance {
    <#  Cheap structural check. Returns $null when balanced, or a description when not. #>
    param([Parameter(Mandatory)][string]$Path)
    $text = [System.IO.File]::ReadAllText($Path)
    $tokens = Get-KvTokens $text
    $depth = 0
    foreach ($t in $tokens) {
        if ($t.Kind -eq 'open') { $depth++ }
        elseif ($t.Kind -eq 'close') {
            $depth--
            if ($depth -lt 0) { return 'closes a block that was never opened' }
        }
    }
    if ($depth -ne 0) { return "$depth block(s) left unclosed" }
    return $null
}

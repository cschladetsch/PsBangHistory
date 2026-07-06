#requires -Module PSReadLine

# ~ -based bash bang-history emulation for PowerShell.
#
# Supported syntax:
#   ~~              last command                 (bash !!)
#   ~$              last word of last command     (bash !$)
#   ~-N             Nth-previous command           (bash !-N)
#   ~-N:$           last word of Nth-previous cmd
#   ~-N:^           first arg of Nth-previous cmd
#   ~-N:*           all args of Nth-previous cmd
#   ~-N:K           word K (0=command name) of Nth-previous cmd
#   ~-N:A-B         word range A..B of Nth-previous cmd
#   ~N              history event N by absolute Id     (bash !N)
#   ~N:$ / :^ / :* / :K / :A-B   same selectors, applied to event N
#   ~[text]         most recent cmd containing "text"   (bash !?text?, substring anywhere)
#   ~[text]:$ / :^ / :* / :K / :A-B   same selectors, applied to matched command
#   ~word           most recent cmd starting with "word" (bash !word, prefix match)
#   ~word:$ etc     same selectors, applied to the prefix-matched command
#   ~-N:K*          words K..end of Nth-previous command (bash !-N:K*)
#   ~~:gs/old/new/  last command with every "old" replaced by "new" (bash !!:gs/old/new/)
#                   note: neither "old" nor "new" may contain a literal "/"
#   ^old^new^       quick substitution: last command, first "old" replaced by "new", re-run
#
# ~# (bash's "current typed line so far") is not supported — there's no
# reliable hook for the not-yet-submitted buffer text outside the Enter
# handler itself.
#
# Behaviour: pressing Enter on a line containing ~ tokens expands them into
# the buffer and does NOT run the line (preview step). Press Enter again to
# actually execute. Dot-source this from $PROFILE.

function Split-BangWords {
    param([string]$Line)
    [regex]::Matches($Line, '(?:[^\s"'']+|"[^"]*"|''[^'']*'')+') |
        ForEach-Object { $_.Value }
}

function Select-BangWords {
    param([string[]]$Words, [string]$Selector)

    if (-not $Selector) { return ($Words -join ' ') }

    switch -regex ($Selector) {
        '^\$$' { return $Words[-1] }
        '^\^$' { return $Words[1] }
        '^\*$' { return ($Words[1..($Words.Count - 1)] -join ' ') }
        '^(\d+)\*$' {
            $k = [int]$Matches[1]
            return ($Words[$k..($Words.Count - 1)] -join ' ')
        }
        '^\d+$' { return $Words[[int]$Selector] }
        '^(\d+)-(\d+)$' {
            $a = [int]$Matches[1]; $b = [int]$Matches[2]
            return ($Words[$a..$b] -join ' ')
        }
        '^gs/([^/]*)/([^/]*)/?$' {
            $findText = $Matches[1]; $replaceText = $Matches[2]
            return (($Words -join ' ') -replace [regex]::Escape($findText), $replaceText)
        }
        default { return ($Words -join ' ') }
    }
}

function Get-BangCommandLine {
    param([string]$Ref)

    if ($Ref -eq '~~') {
        $h = Get-History -Count 1
    }
    elseif ($Ref -match '^~-(\d+)$') {
        $n = [int]$Matches[1]
        $h = Get-History -Count $n | Select-Object -First 1
    }
    elseif ($Ref -match '^~(\d+)$') {
        $id = [int]$Matches[1]
        $h = Get-History -Id $id -ErrorAction SilentlyContinue
    }
    elseif ($Ref -match '^~\[(.+)\]$') {
        $needle = $Matches[1]
        $h = Get-History | Where-Object { $_.CommandLine -like "*$needle*" } |
             Select-Object -Last 1
    }
    elseif ($Ref -match '^~([A-Za-z_][\w.\-\/]*)$') {
        $prefix = $Matches[1]
        $h = Get-History | Where-Object { $_.CommandLine -like "$prefix*" } |
             Select-Object -Last 1
    }
    else {
        return $null
    }

    if (-not $h) { return $null }
    return $h.CommandLine
}

function Expand-BangHistory {
    param([string]$Line)

    # Quick substitution: ^old^new^ (or ^old^new) operates on the entire
    # last command, replacing the first occurrence of "old" with "new",
    # then previews the result exactly like every other token — bash's !!
    # implied re-run happens on the user's confirming second Enter, not here.
    if ($Line -match '^\^([^\^]+)\^([^\^]*)\^?$') {
        $findText = $Matches[1]; $replaceText = $Matches[2]
        $last = Get-BangCommandLine -Ref '~~'
        if ($last) {
            $rx = [regex]::new([regex]::Escape($findText))
            return $rx.Replace($last, $replaceText, 1)   # first occurrence only
        }
        return $Line
    }

    # normalize the !$-equivalent shorthand first
    $Line = $Line -replace '~\$', '~~:$'

    $refPattern = '~~|~-\d+|~\d+|~\[[^\]]+\]|~[A-Za-z_][\w.\-\/]*'
    $selPattern = '\$|\^|\*|\d+\*|\d+(?:-\d+)?|gs/[^/]*/[^/]*/?'
    $pattern = "(?<ref>$refPattern)(?::(?<sel>$selPattern))?"

    $result = [regex]::Replace($Line, $pattern, {
        param($m)
        $ref = $m.Groups['ref'].Value
        $sel = $m.Groups['sel'].Value

        $cmd = Get-BangCommandLine -Ref $ref
        if (-not $cmd) { return $m.Value }   # no match, leave token untouched

        $words = Split-BangWords -Line $cmd
        return (Select-BangWords -Words $words -Selector $sel)
    })

    return $result
}

try {
    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        param($key, $arg)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        if ($line -match '~') {
            $expanded = Expand-BangHistory -Line $line
            if ($expanded -ne $line) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $expanded)
                return
            }
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}
catch {
    # Non-interactive host (e.g. CI test runner) — key handler registration
    # isn't meaningful there. The Expand-BangHistory / Get-BangCommandLine
    # functions above are still defined and testable.
    Write-Verbose "Skipped PSReadLine key handler registration: $_"
}

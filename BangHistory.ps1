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
#   ~[text]         most recent cmd containing "text"   (bash !text, but substring not prefix)
#   ~[text]:$ / :^ / :* / :K / :A-B   same selectors, applied to matched command
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
        '^\d+$' { return $Words[[int]$Selector] }
        '^(\d+)-(\d+)$' {
            $a = [int]$Matches[1]; $b = [int]$Matches[2]
            return ($Words[$a..$b] -join ' ')
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
    else {
        return $null
    }

    if (-not $h) { return $null }
    return $h.CommandLine
}

function Expand-BangHistory {
    param([string]$Line)

    # normalize the !$-equivalent shorthand first
    $Line = $Line -replace '~\$', '~~:$'

    $pattern = '(?<ref>~~|~-\d+|~\d+|~\[[^\]]+\])(?::(?<sel>\$|\^|\*|\d+(?:-\d+)?))?'

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

Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($line -match '~') {
        $expanded = Expand-BangHistory -Line $line
        if ($expanded -ne $line) {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($expanded)
            return
        }
    }

    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

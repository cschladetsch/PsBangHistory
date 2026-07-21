#requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/../BangHistory.ps1"

    # Fake history buffer, Id ascending, used by every test via a mocked
    # Get-BangHistoryBuffer — this bypasses both Get-History and any real
    # PSReadLine persisted history file, keeping tests deterministic.
    $script:FakeHistory = @(
        [pscustomobject]@{ Id = 15; CommandLine = 'git status' }
        [pscustomobject]@{ Id = 16; CommandLine = 'docker run -d --name api-server -p 8080:80 nginx' }
        [pscustomobject]@{ Id = 17; CommandLine = 'vim server.config.json' }
        [pscustomobject]@{ Id = 18; CommandLine = 'git add server.config.json' }
    )

    function Get-BangHistoryBuffer {
        return $script:FakeHistory
    }
}

Describe 'Split-BangWords' {
    It 'splits a simple command into words' {
        Split-BangWords -Line 'git add server.config.json' |
            Should -Be @('git', 'add', 'server.config.json')
    }

    It 'keeps double-quoted segments as a single word' {
        Split-BangWords -Line 'git commit -m "fix bug"' |
            Should -Be @('git', 'commit', '-m', '"fix bug"')
    }
}

Describe 'Select-BangWords' {
    BeforeAll {
        $script:Words = 'git', 'add', 'server.config.json'
    }

    It 'returns the last word for $' {
        Select-BangWords -Words $script:Words -Selector '$' | Should -Be 'server.config.json'
    }

    It 'returns the first arg for ^' {
        Select-BangWords -Words $script:Words -Selector '^' | Should -Be 'add'
    }

    It 'returns all args for *' {
        Select-BangWords -Words $script:Words -Selector '*' | Should -Be 'add server.config.json'
    }

    It 'returns word K by index' {
        Select-BangWords -Words $script:Words -Selector '0' | Should -Be 'git'
    }

    It 'returns a word range A-B' {
        $words = 'a', 'b', 'c', 'd', 'e'
        Select-BangWords -Words $words -Selector '1-3' | Should -Be 'b c d'
    }

    It 'returns the whole line when no selector given' {
        Select-BangWords -Words $script:Words -Selector $null | Should -Be 'git add server.config.json'
    }
}

Describe 'Get-BangCommandLine' {
    It 'resolves ~~ to the last command' {
        Get-BangCommandLine -Ref '~~' | Should -Be 'git add server.config.json'
    }

    It 'resolves ~-N to the Nth-previous command' {
        # bash convention: !-1 == !! (most recent). !-2 is the 2nd-most-recent
        # event, i.e. one before the last, not two events further back.
        Get-BangCommandLine -Ref '~-2' | Should -Be 'vim server.config.json'
    }

    It 'resolves ~N to an absolute history id' {
        Get-BangCommandLine -Ref '~17' | Should -Be 'vim server.config.json'
    }

    It 'returns $null for an absolute id that does not exist' {
        Get-BangCommandLine -Ref '~999' | Should -BeNullOrEmpty
    }

    It 'resolves ~[text] to the most recent matching command' {
        Get-BangCommandLine -Ref '~[api-server]' | Should -Be 'docker run -d --name api-server -p 8080:80 nginx'
    }

    It 'returns $null for an unrecognized ref' {
        Get-BangCommandLine -Ref 'not-a-ref' | Should -BeNullOrEmpty
    }
}

Describe 'Expand-BangHistory' {
    It 'expands ~~ to the full last command' {
        Expand-BangHistory -Line '~~' | Should -Be 'git add server.config.json'
    }

    It 'expands ~$ to the last word of the last command' {
        Expand-BangHistory -Line 'vim ~$' | Should -Be 'vim server.config.json'
    }

    It 'expands ~* to all args of the last command' {
        Expand-BangHistory -Line 'echo ~*' | Should -Be 'echo add server.config.json'
    }

    It 'expands ~-N:$ to the last word of the Nth-previous command' {
        Expand-BangHistory -Line 'less ~-3:$' | Should -Be 'less nginx'
    }

    It 'expands ~N (absolute) with a selector' {
        Expand-BangHistory -Line 'echo ~17:^' | Should -Be 'echo server.config.json'
    }

    It 'expands ~[text]:K (search plus word selector)' {
        Expand-BangHistory -Line 'docker logs ~[api-server]:3' | Should -Be 'docker logs --name'
    }

    It 'expands ~word to a prefix-matched command (bash !word semantics)' {
        Expand-BangHistory -Line '~git' | Should -Be 'git add server.config.json'
    }

    It 'prefix match requires the start of the line, not just a substring' {
        # "server" appears inside "vim server.config.json" but does not
        # prefix it, so ~server should not resolve to that command.
        Expand-BangHistory -Line '~server' | Should -Be '~server'
    }

    It 'expands N* to select from word N to the end' {
        Expand-BangHistory -Line '~16:2*' | Should -Be '-d --name api-server -p 8080:80 nginx'
    }

    It 'expands gs/old/new/ as a global substitution across the command' {
        Expand-BangHistory -Line '~~:gs/server.config.json/prod.config.json/' |
            Should -Be 'git add prod.config.json'
    }

    It 'expands ^old^new^ quick substitution against the last command' {
        Expand-BangHistory -Line '^server^client^' | Should -Be 'git add client.config.json'
    }

    It 'expands ^old^new (no trailing caret) the same way' {
        Expand-BangHistory -Line '^server^client' | Should -Be 'git add client.config.json'
    }

    It 'leaves unmatched ~ tokens untouched' {
        Expand-BangHistory -Line '~5000' | Should -Be '~5000'
    }

    It 'leaves lines with no ~ token completely unchanged' {
        Expand-BangHistory -Line 'git status' | Should -Be 'git status'
    }
}

Describe 'Resolve-BangHistoryExpansion' {
    # Regression coverage for a real bug: the Enter key handler used to gate
    # on "does the line contain a literal ~" before calling
    # Expand-BangHistory at all. ^old^new^ contains no ~, so that guard
    # silently skipped it in every real session even though
    # Expand-BangHistory itself resolved it correctly — the README's own
    # "quick fix a typo" demo never actually worked when typed at a live
    # prompt. Resolve-BangHistoryExpansion is what both the key handler and
    # these tests call now, so the two can't drift apart again.

    It 'resolves ^old^new^ even though the line contains no ~' {
        '^server^client^' | Should -Not -Match '~'
        Resolve-BangHistoryExpansion -Line '^server^client^' | Should -Be 'git add client.config.json'
    }

    It 'resolves ~~ tokens the same as Expand-BangHistory' {
        Resolve-BangHistoryExpansion -Line '~~' | Should -Be 'git add server.config.json'
    }

    It 'returns $null when there is nothing to expand' {
        Resolve-BangHistoryExpansion -Line 'git status' | Should -BeNullOrEmpty
    }

    It 'returns $null for an unmatched ~ token (same text in and out)' {
        Resolve-BangHistoryExpansion -Line '~5000' | Should -BeNullOrEmpty
    }
}

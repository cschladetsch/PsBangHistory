#requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/../BangHistory.ps1"

    # Fake history buffer, Id ascending, used by every test via mocked Get-History.
    $script:FakeHistory = @(
        [pscustomobject]@{ Id = 15; CommandLine = 'git status' }
        [pscustomobject]@{ Id = 16; CommandLine = 'docker run -d --name api-server -p 8080:80 nginx' }
        [pscustomobject]@{ Id = 17; CommandLine = 'vim server.config.json' }
        [pscustomobject]@{ Id = 18; CommandLine = 'git add server.config.json' }
    )

    function Get-History {
        param(
            [int]$Count,
            [int]$Id
        )
        if ($PSBoundParameters.ContainsKey('Id')) {
            return $script:FakeHistory | Where-Object { $_.Id -eq $Id }
        }
        if ($PSBoundParameters.ContainsKey('Count')) {
            return $script:FakeHistory | Select-Object -Last $Count
        }
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
        # 4 entries total; -2 back from "current" (not-yet-in-history) means
        # 2nd most recent of the last 2 entries.
        Get-BangCommandLine -Ref '~-2' | Should -Be 'docker run -d --name api-server -p 8080:80 nginx'
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

    It 'expands ~-N:$ to the last word of the Nth-previous command' {
        Expand-BangHistory -Line 'less ~-3:$' | Should -Be 'less server.config.json'
    }

    It 'expands ~N (absolute) with a selector' {
        Expand-BangHistory -Line 'echo ~17:^' | Should -Be 'echo vim'
    }

    It 'expands ~[text]:K (search plus word selector)' {
        Expand-BangHistory -Line 'docker logs ~[api-server]:3' | Should -Be 'docker logs --name'
    }

    It 'leaves unmatched ~ tokens untouched' {
        Expand-BangHistory -Line '~5000' | Should -Be '~5000'
    }

    It 'leaves lines with no ~ token completely unchanged' {
        Expand-BangHistory -Line 'git status' | Should -Be 'git status'
    }
}

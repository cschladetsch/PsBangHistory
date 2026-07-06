# PsBangHistory

Bash-style bang-history expansion for PowerShell, using `~` instead of `!` (since `!` isn't available as a bare sigil in PowerShell).

## Syntax

| Token          | Meaning                                      | Bash equivalent |
|----------------|-----------------------------------------------|------------------|
| `~~`           | last command                                  | `!!`             |
| `~$`           | last word of last command                     | `!$`             |
| `~-N`          | Nth-previous command                          | `!-N`            |
| `~-N:$`        | last word of Nth-previous command             | `!-N:$`          |
| `~-N:^`        | first arg of Nth-previous command             | `!-N:^`          |
| `~-N:*`        | all args of Nth-previous command              | `!-N:*`          |
| `~-N:K`        | word K (0 = command name) of Nth-previous cmd | `!-N:K`          |
| `~-N:A-B`      | word range A..B of Nth-previous command       | `!-N:A-B`        |
| `~N`           | history event N by absolute Id                | `!N`             |
| `~N:$` etc     | same selectors, applied to event N            | `!N:$` etc       |
| `~[text]`      | most recent command containing `text` anywhere | `!?text?`       |
| `~[text]:$` etc | same selectors, applied to the matched command | `!text:$` etc   |
| `~word`        | most recent command *starting with* `word`   | `!word`          |
| `~word:$` etc  | same selectors, applied to the prefix-matched command | `!word:$` etc |
| `~-N:K*`       | words K..end of Nth-previous command          | `!-N:K*`         |
| `~~:gs/old/new/` | last command, every `old` replaced with `new` | `!!:gs/old/new/` |
| `^old^new^`    | last command, first `old` replaced with `new` | `^old^new^`      |

## Install

```powershell
. "C:\path\to\PsBangHistory\BangHistory.ps1"
```

Or add that line to `$PROFILE` to load on every session.

## Behaviour

Pressing Enter on a line containing a `~` token expands it into the buffer and stops — it does not execute. Press Enter again on the now-expanded (token-free) line to run it. This is a deliberate preview/confirm step, not a bug.

**If an expansion resolves to the wrong thing**, press **Ctrl+Z** (PowerShell's default Undo binding) to revert the buffer back to exactly what you typed, fix the token, and try again.

Operates on `Get-History` (session command history), the direct analog of what bash's bang-notation reads from — not the separate PSReadLine persisted history file.

Bash's `!#` (the not-yet-submitted current line) has no equivalent here — there's no reliable hook into unsubmitted buffer text outside the Enter handler itself.

`gs/old/new/` — neither `old` nor `new` may contain a literal `/`, since `/` is the field delimiter.

## Demos

**Rerun the last command**
```powershell
PS> docker build -t myapp .
PS> ~~
```

**Reuse an argument across a different command**
```powershell
PS> vim server.config.json
PS> git add ~$
# expands to: git add server.config.json
```

**Search history and extract an argument**
```powershell
PS> docker run -d --name api-server -p 8080:80 nginx
PS> ...ten commands later...
PS> docker logs ~[api-server]:2
```

**The safety net — preview before anything destructive runs**
```powershell
PS> rm -Recurse ~-5:*
# buffer shows the fully expanded path before anything executes
# e.g. rm -Recurse -Force C:\builds\output\*
# only runs on the second Enter
```

**Absolute recall by history id**
```powershell
PS> Get-History | Select-Object Id, CommandLine -Last 20
PS> ~142
```

**Quick fix a typo/detail and re-run without retyping the whole command**
```powershell
PS> git push origin mian
PS> ^mian^main^
# expands to: git push origin main
```

**Prefix match — bash's actual !string behavior**
```powershell
PS> git commit -m "fix bug"
PS> ~git
# most recent command starting with "git" — not just containing it anywhere
```

**Global substitution across an entire command**
```powershell
PS> docker build -t myapp:v1.2.3 .
PS> ~~:gs/v1.2.3/v1.2.4/
# expands to: docker build -t myapp:v1.2.4 .
```

## License

MIT

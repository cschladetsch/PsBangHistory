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
| `~[text]`      | most recent command containing `text`         | `!text` (bash uses prefix match; this is substring) |
| `~[text]:$` etc | same selectors, applied to the matched command | `!text:$` etc   |

## Install

```powershell
. "C:\path\to\PsBangHistory\BangHistory.ps1"
```

Or add that line to `$PROFILE` to load on every session.

## Behaviour

Pressing Enter on a line containing a `~` token expands it into the buffer and stops — it does not execute. Press Enter again on the now-expanded (token-free) line to run it. This is a deliberate preview/confirm step, not a bug.

Operates on `Get-History` (session command history), the direct analog of what bash's bang-notation reads from — not the separate PSReadLine persisted history file.

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

## License

MIT

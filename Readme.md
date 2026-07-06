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

## Examples

```powershell
PS> git status
PS> ~~
# buffer -> git status, Enter again to run

PS> code myfile.cpp
PS> vim ~$
# buffer -> vim myfile.cpp

PS> ~[docker]:^
# first arg of the most recent command containing "docker"
```

## License

MIT

# PowerShell Profile

A modular PowerShell 7 (pwsh) profile for Windows, organized as a thin bootstrap
plus a set of version-controlled helper scripts. Heavy GNU commands come from
[Microsoft.Coreutils](https://learn.microsoft.com/windows/terminal) (winget), and
per-machine config lives in a git-ignored `custom/` folder.

## Layout

```
Microsoft.PowerShell_profile.ps1   ← thin bootstrap (10 lines); dot-sources main.ps1
main.ps1                           ← real entry point: import modules + load helpers/*
helpers/
  00-env.ps1           environment variables
  20-cache.ps1         starship / zoxide / uv init (cached, not version-controlled)
  30-aliases.ps1       launch wrappers (fvim, lg, zj, nvimn, sshrsa, profileedit, profilereload)
  30-linux-aliases.ps1 which / export / unset (coreutils doesn't provide these)
  30-netinfo.ps1       network info (netinfo / ni)
  30-proxy.ps1         proxy on/off/status/toggle/reset (proxy / pxy)
  30-psreadline.ps1    PSReadLine config, history, key bindings, fzf
  30-win.ps1           Windows settings launchers (winset / ws)
  99-custom-loader.ps1 auto-load per-machine scripts from ../custom (loads LAST)
custom/                ← git-ignored (except .gitkeep); private per-machine scripts
Modules/               ← git-ignored (external modules)
Scripts/               ← git-ignored
```

Files are loaded in **name order** (`Sort-Object Name`), so the numeric prefixes
(`00`, `20`, `30`, `99`) control the sequence: env → cache → features → custom.

## Requirements

- **PowerShell 7+** (`pwsh`) — not Windows PowerShell 5.1.
- Optionally, for full functionality:
  - [`Microsoft.Coreutils`](https://learn.microsoft.com/windows/terminal) (`winget install Microsoft.Coreutils`) — provides `ls`, `cat`, `grep`, `wc`, `du`, `df`, `find`, etc.
  - [`starship`](https://starship.rs/), [`zoxide`](https://github.com/ajeetdsouza/zoxide), [`uv`](https://github.com/astral-sh/uv) — init scripts are generated on first run into `$LOCALAPPDATA/pwsh_cache`.
  - [`lazygit`](https://github.com/jesseduffield/lazygit), [`zellij`](https://zellij.dev/), [`nvim`](https://neovim.io/), [`fzf`](https://github.com/junegunn/fzf) — used by the helper functions/aliases.

## Install

This folder **is** your PowerShell profile directory. Either clone into it, or
symlink it:

```powershell
git clone <repo-url> "$env:USERPROFILE\Documents\PowerShell"
```

Or, if your profile lives elsewhere, drop `Microsoft.PowerShell_profile.ps1` and
`main.ps1` there and point `$PSScriptRoot` at the rest. Restart pwsh (or run
`. $PROFILE`) to load.

## How it works

1. pwsh runs `Microsoft.PowerShell_profile.ps1` (the **shell**). It only does one
   thing: resolve `main.ps1` next to it and dot-source it.
2. `main.ps1` imports `Microsoft.WinGet.CommandNotFound`, then dot-sources every
   `helpers/*.ps1` in sorted order. Each helper is wrapped in `try/catch` so a
   broken helper doesn't break the whole profile.
3. `99-custom-loader.ps1` (last) loads any `*.ps1` in `custom/` — these can
   override helpers.

### Why a shell + main.ps1?

Keeping `Microsoft.PowerShell_profile.ps1` tiny means auto-modifying tools (the
coreutils installer appends an inline block to it) have nothing to fight over,
and the real logic stays in reviewable, version-controlled files.

## Per-machine config: `custom/`

`custom/` is git-ignored except for `.gitkeep`, so each machine can carry its own
env vars, proxies, and private aliases without polluting the shared repo. Scripts
inside are dot-sourced into the global scope (so they can override helpers) and
load last. Use a numeric prefix to control order, e.g.:

```powershell
# custom/10-env.ps1
$env:MY_TOOL_HOME = 'C:\Tools\mything'
function work { Set-Location C:\Projects\work }
```

Subfolders are supported too (`custom/aliases/`, `custom/env/`).

## Linux-style commands

PowerShell already aliases many GNU commands (`ls`, `cp`, `mv`, `rm`, `cat`,
`pwd`, `ps`, `kill`, `man`, `tee`, …). For the rest, install **Microsoft.Coreutils**
via winget — it provides real `wc`, `head`, `tail`, `touch`, `ln`, `du`, `df`,
`grep`, `find`, `sort`, `cut`, `tr`, `xargs`, … that behave like their GNU
counterparts.

`30-linux-aliases.ps1` only defines the commands coreutils **lacks**:

| Command | Description |
| --- | --- |
| `which <cmd>` | Locate a command (resolves PATH); `-a` lists all matches |
| `which` `-a` | List every match, not just the first |
| `export VAR=val` / `unset VAR` | Set / remove an environment variable |
| `tree` | Delegates to a real `tree.exe` if installed; otherwise an ASCII fallback |

## Helper reference

| Command | File | Description |
| --- | --- | --- |
| `fvim [...]` | `30-aliases.ps1` | Open Neovim (no args = empty buffer) |
| `lg` | `30-aliases.ps1` | Launch `lazygit` |
| `zj` | `30-aliases.ps1` | Launch `zellij` |
| `nvimn [-clean] [file]` | `30-aliases.ps1` | Neovim with `-u NONE` (clean config) |
| `sshrsa <host>` | `30-aliases.ps1` | `ssh` with legacy `ssh-rsa` algorithms enabled |
| `profileedit` | `30-aliases.ps1` | Open the profile entry (`main.ps1`) in Neovim |
| `profilereload` | `30-aliases.ps1` | Re-load the profile (`. $PROFILE`) |
| `netinfo [-Help]` | `30-netinfo.ps1` | Show local/public IP and proxy status (`ni` in help text) |
| `proxy [on\|off\|status\|toggle\|reset]` | `30-proxy.ps1` | Manage `HTTP(S)_PROXY` / `http(s)_proxy` and .NET proxy (`pxy`) |
| `winset [<target>]` / `ws` | `30-win.ps1` | Launch deep Windows settings / admin tools (see `ws help`) |
| `vhist` | `30-psreadline.ps1` | Open the PSReadLine history file in Neovim |
| `chist` | `30-psreadline.ps1` | Deduplicate the PSReadLine history file |

PSReadLine is configured in `30-psreadline.ps1`: Emacs-style editing, history
prediction (ListView), sensitive-command filtering from history, and fzf chords
(`Ctrl+t` file, `Ctrl+r` history). History is stored at
`~\ .powershell\pwsh_history.txt`.

## Microsoft.Coreutils & git

The coreutils installer appends an inline block to `Microsoft.PowerShell_profile.ps1`
on install/upgrade. That block is **local-only noise** — it's excluded from git so
it never ends up in a commit:

```powershell
git update-index --skip-worktree Microsoft.PowerShell_profile.ps1
```

Run that once per machine (or on any machine that has coreutils installed). To
edit the shell itself later: `git update-index --no-skip-worktree …`, edit, commit,
then re-apply `--skip-worktree`.

## Adding a helper

1. Create `helpers/NN-name.ps1` (pick a numeric prefix for ordering).
2. Put functions/aliases there. Keep it self-contained and `try/catch`-friendly.
3. Reload: `profilereload` (or restart pwsh).

## Notes

- `Modules/` and `Scripts/` are git-ignored (external/non-shared content).
- `.workbuddy/` is git-ignored (agent memory).
- Generated init scripts (starship/zoxide/uv) live in `$LOCALAPPDATA/pwsh_cache`,
  never in this repo.

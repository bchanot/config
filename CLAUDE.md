# CLAUDE.md — config (personal dotfiles)

Project context for Claude. Global preferences in `~/.claude/CLAUDE.md` apply on top.

## What this is

Personal dotfiles repo. **Archetype: dotfiles-meta** (meta/config, not an application).
Produces vim + bash configuration deployed by `install.sh`. Private/personal audience.

- Public: no
- Database: none
- Stack: POSIX/bash shell scripts + vimscript
- Distribution: `git clone` + `./install.sh` (OS auto-detected)

## Layout

```
remote-install.sh     curl|bash bootstrap: ensure git, clone/pull, run install.sh
install.sh            one-shot installer (OS auto-detected)
vim/vimrc             vim config (pathogen, molokai, syntastic, NERDTree)
vim/autoload/         pathogen loader (committed)
vim/colors/           molokai colorscheme (committed)
bash/bashrc-{linux,osx}          OS-detected bashrc
bin/{dt,dtach-router,claude-provider}   CLI scripts deployed to ~/.local/bin
etc/profile.d/disk-usage-warning.sh     login-time low-disk warning → /etc/profile.d (Linux only)
etc/tmpfiles.d/tmp.conf                 disk-backed /tmp cleanup rules (offer: /tmp on disk)
etc/systemd/ssh.service.d/override.conf sshd OOM-exempt drop-in (offer: SSH memory guard)
etc/default/earlyoom                    earlyoom args, spare sshd / kill node first (same offer)
cloudpex/{cloudpex,install.sh,README.md} on-demand SMB mount helper → /usr/local/bin; site values
                                         prompted at install → /etc/cloudpex.conf, never in the script (FR docs)
.claude/{tasks,memory,audits}/   Claude working state
```

`/tmp` is a RAM-backed tmpfs on Ubuntu (50% of RAM): agent runs fill it, which is why
install.sh offers to mask `tmp.mount`. Swap is not the fix (the cap and ENOSPC stay).

`pymupdf`/`markdown_py` are NOT tracked — they are pipx entry-point shims,
recreated by `pipx install PyMuPDF Markdown` in install.sh.
`claude-provider` reads `$OPENROUTER_API_KEY` from the env — never hardcode it (the
original had a live key; it was scrubbed — see decisions/blockers).

## Commands

| Task  | Command                                  |
| ----- | ---------------------------------------- |
| Lint  | `shellcheck *.sh cloudpex/install.sh cloudpex/cloudpex bash/bashrc-*` |
| Syntax check | `bash -n install.sh remote-install.sh cloudpex/install.sh` |
| Install | `./install.sh` (OS auto-detected) |
| Remote install | `curl -fsSL <raw>/remote-install.sh \| bash` |

No build, no test suite. Lint = shellcheck.

## Conventions

- Shell scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, quote all expansions, keep shellcheck clean.
- Installer must stay **idempotent** (re-runnable without breaking state) and use `$SCRIPT_DIR`-relative paths.
- bashrc files: tabs for indentation (existing style). Style nits (legacy backticks) tolerated — don't churn.
- No secrets in any tracked file. Use placeholders if config ever needs tokens.

## Known issues (see .claude/audits/ONBOARD_REPORT.md)

- `vim/vimrc` `GenerateClassC` uses bare `name` instead of `a:name` → `:ClassC` errors (E121). Vim domain, not yet fixed.
- bashrc files use legacy backticks (`SC2006`) — cosmetic.

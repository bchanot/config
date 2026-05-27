# Onboard Report — config

Date: 2026-05-27 · Mode: right-sized (inline, no subagent fan-out — 8 files justify it)

## Profile

- Archetype: **dotfiles-meta** (meta/config) — confidence HAUTE
- Stack: bash + vimscript
- Public: no (personal/private)
- Database: none
- Size: 8 tracked files, ~405 lines
- audit_stack run: analyze, code-clean, cso, doc (SEO/GEO/design/perf/a11y N/A)

## Scores

| Domain     | Score | Note                                                      |
| ---------- | ----- | --------------------------------------------------------- |
| analyze    | 70    | tiny + clear; installer logic was broken (now fixed)      |
| code-clean | 75    | shellcheck-clean installer; bashrc style nits remain      |
| cso (sec)  | 90    | no secrets; only generic `curl`-less local-exec risk      |
| doc        | 95    | was 0 (no README); now README + CLAUDE.md created         |

## What's good (protect this)

- vim config is coherent: pathogen + molokai + syntastic (C `-Wall -Werror -Wextra`) + NERDTree + 42 canonical-class helpers. Self-contained, plugins committed.
- bashrc-linux has a thoughtful git-aware prompt + command timer.
- No secrets, no `curl|sh` in any doc, no hardcoded tokens.
- Per-target bashrc split (server/linux/osx) is a clean separation.

## What was wrong

### Fixed this session (install.sh)
- **[Critique]** server + osx branches `cp /tmp/config/bash/bashrc-*` — `/tmp/config` never populated → both targets silently installed no bashrc. Now SCRIPT_DIR-relative.
- **[Haute]** `[ "$1" == "server" ]` bashism under `#!/bin/sh` → fails on dash. Now `#!/usr/bin/env bash`.
- **[Haute]** `cp /tmp/nerdtree ~/.vim/bundle/` missing `-r` (nerdtree is a dir) → copy fails. Now clones directly into bundle.
- **[Moyenne]** `apt-get` ran unconditionally including for `osx` → fails on macOS. Now guarded by `command -v apt-get`.
- **[Moyenne]** redundant molokai clone (already committed in `vim/colors/`). Dropped.
- **[Basse]** unquoted `$HOME`/`$1`, no `set -eu`, no-op `source ~/.bashrc` at end, `/tmp/nerdtree`+`/tmp/config` never cleaned. All resolved. shellcheck now CLEAN.

### Still open (not in this session's scope)
- **[Moyenne]** `vim/vimrc` `GenerateClassC` uses bare `name` instead of `a:name` → `:ClassC` errors with E121. See BLK-001.
- **[Basse]** `bash/bashrc-*` use legacy backticks (SC2006) + `$((...$var...))` (SC2004). Cosmetic; deferred.

## Missing files — created this session
README.md · CLAUDE.md · .gitignore · .claude/memory/* · .claude/tasks/TODO.md · .claude/settings.json

Not created (personal repo, optional): LICENSE, CHANGELOG.md, CONTRIBUTING.md.

## Next steps
See `.claude/tasks/TODO.md` for the prioritized backlog.

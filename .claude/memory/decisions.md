# Decisions

Design/architecture choices. Caveman + English.

## BDR-001 — Installer rewritten bash, not POSIX sh
2026-05-27. `install.sh` used `#!/bin/sh` but `[ "$1" == "x" ]` (bashism) → breaks on dash.
Switched shebang to `#!/usr/bin/env bash` + `set -euo pipefail`. Repo targets apt-get systems,
bash always present. Alternative (stay POSIX, use `=`) rejected — bash gives brace expansion +
arrays if needed later. Status: done.

## BDR-002 — Installer paths relative to SCRIPT_DIR
2026-05-27. Old script mixed `/tmp/config/bash/...` (never populated) and relative `bash/...`.
server + osx branches referenced nonexistent `/tmp/config` → silent fail. Now compute
`SCRIPT_DIR` once, all paths relative to it. Works from any cwd. Status: done.

## BDR-003 — apt-get guarded by command -v
2026-05-27. `apt-get` ran unconditionally even for `osx` target → fails on macOS.
Wrapped in `if command -v apt-get`. osx skips system packages. Status: done.

## BDR-004 — remote-install.sh bootstrap: clone ~/config, idempotent pull
2026-05-27. Added curl|bash bootstrap. Clones repo to `$HOME/config` (env-overridable
REPO_URL/CLONE_DIR/BRANCH), pulls if exists, ensures git first, then `bash install.sh`.
Alt rejected: temp-dir + tarball download (no git dep) — kept git path, simpler + repo
needs git anyway. Risk noted: curl|bash runs unreviewed remote code (archetype pain point);
mitigated by HTTPS + pinned branch + manual fallback in README, not eliminated. Status: done.

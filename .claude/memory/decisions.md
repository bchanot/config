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

## BDR-005 — Remote desktop via gnome-remote-desktop --system, not xrdp
2026-06-23. Target machine = Wayland-only GNOME (Shell asserts XDG_SESSION_TYPE=wayland). xrdp's
Xorg backend can't satisfy it → session dies instantly on login. Chose gnome-remote-desktop system
"Remote Login" (GNOME-native, Wayland, RDP 3389, TLS, fresh GDM session). Auth 2-layer: shared gate
creds (`set-credentials`) → per-user GDM PAM; gate creds required else mstsc 0x904 (BLK-004).
Implemented install.sh `setup_remote_desktop` + `ensure_rdp_credentials`. Connection confirmed live.
Alts rejected: (a) force Xorg GDM + xrdp — sacrifices Wayland desktop, fragile; (b) VNC (wayvnc) —
RDP preferred (mstsc native on Win client, TLS); (c) g-r-d user "Desktop Sharing" mode — shares
existing local session, wanted independent headless login. See LRN-004, BLK-004. Status: done.

## BDR-006 — Disk-usage login warning deployed system-wide to /etc/profile.d
2026-06-24. New `etc/profile.d/disk-usage-warning.sh` (POSIX sh, bold-red warn when / or /home ≥85%)
deployed via `sudo install -D -m 0644` to `/etc/profile.d/` from `install_disk_warning()`, gated in
the apt-get Linux block (see LRN-005). Alt rejected: per-user append to `~/.bashrc` — wanted the warn
for EVERY login account on the box, not just the installing user, so system-wide profile.d won. Known
limit: login-shell scope only (non-login terminals miss it). Status: done.

## BDR-007 — dtach resume menu wired login-scope via guarded SOURCE in ~/.profile
2026-06-24. Wired dtach session-resume into `~/.profile` (login scope = once per SSH) as a guarded SOURCE
`case $- in *i*) [ -x ~/.local/bin/dtach-router ] && . … ;;`, NOT `~/.bashrc` (every interactive shell →
menu pops on each tab/subshell). Matches "à la connexion SSH" intent. install.sh `wire_dtach_profile()`
idempotent: awk strips prior block (marker-delimited managed block `# >>> claude-dtach >>>` + legacy
`DT=$(dt ls)…fi` execute block) then re-appends marker block. cc/d aliases live in bashrc-linux (sourced by
.profile BEFORE the router runs → available). Alts rejected: (a) source from `.bashrc` (router's own header
suggests it) — fires too often for login-only intent; (b) keep execute + string-parse — broke the return-based
guard (LRN-006) + fragile parse. Supersedes the old execute+string-parse block. Status: done in repo; live
~/.profile re-migrated this session.

## BDR-008 — config repo licensed GPL-3.0-or-later (copyleft)
2026-06-25. Added LICENSE (verbatim GPLv3 copied from `/usr/share/common-licenses/GPL-3`) + README
`## License` (`GPL-3.0-or-later — see LICENSE`, © 2026 Bastien Chanot). User said "full opensource" → read
as strong COPYLEFT (code + all derivatives stay open), not permissive. SPDX: GPL-3.0-or-later; "or-later"
grant asserted in README per FSF convention, LICENSE holds plain GPLv3 text. Alts rejected: MIT / Apache-2.0
(permissive — allow CLOSED derivatives, weaker open guarantee); Unlicense (public domain, no copyleft).
Repo private (CLAUDE.md Public=no) so license optional, but user wanted one set. Reversible: swap LICENSE +
README line if "full opensource" meant permissive. Status: done in repo (uncommitted).

## BDR-009 — dtach resume menu moved ~/.profile → ~/.bashrc (every interactive shell)
2026-06-25. Reversed BDR-007. Root cause: user works in VS Code Remote-SSH; its Linux integrated terminals are
NON-login interactive shells → read `~/.bashrc`, never `~/.profile` → login-scoped wiring (BDR-007) silently
never fired (LRN-008). Now source dtach-router from `bashrc-linux` via `case $- in *i*) … . dtach-router`;
fires in EVERY interactive shell (covers VS Code, plain SSH via `~/.profile`→`~/.bashrc`, tmux, new tabs).
install.sh `wire_dtach_profile()` → `unwire_dtach_profile()`: strips any stale `~/.profile` block (marker +
legacy) so plain SSH login (sources `~/.bashrc` via `~/.profile`) doesn't prompt twice. Trade-off ACCEPTED
(user chose "simplest"): menu shows in each new terminal tab when sessions exist, not once-per-connection —
the exact noise BDR-007 avoided, now tolerated for VS Code reliability. Alts rejected: (a) once-per-connection
sentinel keyed to `SSH_CONNECTION`/`VSCODE_IPC_HOOK_CLI` in `$XDG_RUNTIME_DIR` — more code, user declined;
(b) VS Code `terminal.integrated` `args:["-l"]` — not carried by dotfiles, same per-tab firing. Supersedes
BDR-007. Status: done in repo; live needs `./install.sh` re-run.

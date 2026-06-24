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

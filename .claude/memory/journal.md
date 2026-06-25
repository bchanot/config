# Journal

3-5 lines/session. Caveman + English.

## 2026-05-27 — onboard (right-sized)
Onboarded dotfiles repo. Archetype dotfiles-meta HAUTE. 8 files, ~405 lines, graphify skipped.
Found + fixed install.sh: broken /tmp/config paths (server+osx silent fail), bashism under sh,
missing cp -r nerdtree, redundant molokai clone, unquoted vars, no set -eu. shellcheck CLEAN.
Created README, CLAUDE.md, .gitignore, .claude memory/tasks/audits. No secrets found.
Open: vimrc GenerateClassC bug (BLK-001), bashrc backtick style nits.
Then: install.sh arg dropped → uname OS-detect (Darwin→osx else linux). Deleted bashrc-server.
Added remote-install.sh curl|bash bootstrap (BDR-004). shellcheck CLEAN. Docs synced.
Committed in 4 atomic commits (chore claude / refactor install / feat remote-install / docs).
Slip: staged deletion swept into commit 1; fixed via soft-reset + restore --staged. Unpushed.

## 2026-06-23 — xrdp install fix
Added/fixed xrdp in install.sh. Found uncommitted block: `enable xrdb` typo (aborts set -e
installer, BLK-003) + `apt-get install xrdp` no -y. Built idempotent install_xrdp() — ssl-cert group
+ polkit .rules (verified polkit 127) + conditional ufw 3389 + enable/restart (LRN-003). Also fixed
adjacent: code-server@"$USER" quoting, broken .profile dtach block (invalid `[ ! grep ]` test +
heredoc unterminated indented EOF). shellcheck + bash -n CLEAN. Not run live / RDP untested.

## 2026-06-23 — RDP pivot xrdp → gnome-remote-desktop
xrdp abandoned (Wayland-only GNOME kills Xorg session). Replaced install_xrdp → setup_remote_desktop
(g-r-d system Remote Login): TLS cert + rdp enable + service. Live debug mstsc 0x904/0x7 = gate creds
empty (BLK-004); 2-layer auth gate→GDM PAM (LRN-004). Added ensure_rdp_credentials (prompt, TTY-guard,
idempotent). Connection CONFIRMED live. install.sh committed 0bd936b (bash -n + shellcheck CLEAN);
push blocked here (HTTPS remote, no creds in env) → user pushes. TPM GKeyFile-fallback warn harmless.

## 2026-06-24 — disk-usage login warning
Added etc/profile.d/disk-usage-warning.sh (POSIX sh, warns bold red when / or /home ≥85%).
install_disk_warning() in install.sh: sudo install -D -m 0644 → /etc/profile.d, gated in apt block
(Linux-only: df --output=pcent GNU-only + /etc/profile.d Debian convention). shellcheck + sh -n CLEAN,
both code paths runtime-verified. README + CLAUDE.md synced. Not committed (master, user to confirm).

## 2026-06-24 — dtach login wiring fix (source not execute) + cc/d aliases
Old ~/.profile block EXECUTED dtach-router + parsed "Aucune session dtach." → broken: executing breaks
the script's return-based interactive guard → falls through → fzf/`dt at >/dev/tty` errors `/dev/tty: No
such device` in every non-interactive login shell (repro'd live on each Bash init). Replaced with guarded
SOURCE `case $- in *i*) ... . dtach-router` via idempotent wire_dtach_profile() (awk strips legacy +
marker block, re-appends marker block). Added cc (create) / d (re-summon) aliases to bashrc-linux.
shellcheck + bash -n CLEAN; migration simulated on real .profile copy. LRN-006 + BDR-007. README synced.
Not committed; live ~/.profile not yet re-migrated.

## 2026-06-25 — dtach menu: ~/.profile → ~/.bashrc (VS Code non-login fix)
User: dtach resume menu never fires at session start, even post-install. Root cause: user runs VS Code
Remote-SSH → its Linux terminals are NON-login → skip ~/.profile (where BDR-007 wired it). Proven by process
tree (VSCODE_IPC_HOOK_CLI, no sshd/login-bash) + provably-correct ~/.profile wiring + existing session yet zero
menu. Fix: source dtach-router from bashrc-linux (every interactive shell); install.sh wire_dtach_profile() →
unwire_dtach_profile() strips stale ~/.profile block (avoids double-prompt on plain SSH). User chose simplest
(per-tab) over once-per-connection sentinel. shellcheck install.sh CLEAN, bash -n OK, strip proven idempotent
on .profile copy. BDR-009 (supersedes BDR-007) + LRN-008. Live needs ./install.sh re-run.

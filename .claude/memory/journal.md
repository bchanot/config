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

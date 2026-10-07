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
guard (LRN-006) + fragile parse. Supersedes the old execute+string-parse block. Status: SUPERSEDED by BDR-009 — done in repo; live
~/.profile re-migrated this session.

## BDR-008 — config repo licensed GPL-3.0-or-later (copyleft)
2026-06-25. Added LICENSE (verbatim GPLv3 copied from `/usr/share/common-licenses/GPL-3`) + README
`## License` (`GPL-3.0-or-later — see LICENSE`, © 2026 Bastien Chanot). User said "full opensource" → read
as strong COPYLEFT (code + all derivatives stay open), not permissive. SPDX: GPL-3.0-or-later; "or-later"
grant asserted in README per FSF convention, LICENSE holds plain GPLv3 text. Alts rejected: MIT / Apache-2.0
(permissive — allow CLOSED derivatives, weaker open guarantee); Unlicense (public domain, no copyleft).
Repo private (CLAUDE.md Public=no) so license optional, but user wanted one set. Reversible: swap LICENSE +
README line if "full opensource" meant permissive. Status: done in repo (committed: LICENSE 40c6524, README License 00d88f7).

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

## BDR-010 — /tmp on disk (mask tmp.mount), swap rejected
2026-09-22. Ubuntu 26.04 mounts /tmp tmpfs size=50% RAM (7.4G of 14G here). Agents fill it → RAM halved +
ENOSPC → shells break. Chose `systemctl mask tmp.mount` + `/etc/tmpfiles.d/tmp.conf` (`D /tmp 10d`, `/var/tmp`
line kept). Offered [y/N] end of install.sh (`offer_tmp_on_disk`), TTY-guarded, idempotent, effective next
reboot (never umount live). Alts rejected: (a) add/grow swap — cap + ENOSPC stay, thrash instead of OOM;
(b) bigger tmpfs `size=` — still RAM; (c) `TMPDIR=/var/tmp` in bashrc — leaky (services, IDE spawns, cron).
Status: done in repo, live apply = user (EVAL-002).

## BDR-011 — SSH memory guard = old-server rules (ssh drop-in + earlyoom), systemd-oomd untouched
2026-09-22. Restored from NAS `RECOVERY/40-systeme/etc`: `ssh.service.d/override.conf` (MemoryMin=256M,
OOMScoreAdjust=-1000) + earlyoom `-r 60 -m 10 -s 10 --avoid '^(sshd|systemd|systemd-logind|dbus-daemon|containerd)$'
--prefer '^(java|node|pnpm|esbuild)$'`. MemoryMin covers sshd cgroup only (logind puts sessions in user.slice)
→ real guard = OOMScoreAdjust + earlyoom (kills ONE largest proc, shell survives). systemd-oomd (Ubuntu default
`ManagedOOMMemoryPressure=kill` 50% on user@.service, kills WHOLE session cgroup) left as-is: zero kills in
journal (fresh install), unproven as shell-killer. `offer_ssh_memory_guard`, [y/N], idempotent, ssh restart keeps
sessions (KillMode=process). Alt rejected: drop-in only — kernel/oomd may still kill whole session. Status: done
in repo, live apply = user.

## BDR-012 — cloudpex site values in /etc/cloudpex.conf, prompted by installer
2026-09-22. User: no IP/user in script. Chose key=value `/etc/cloudpex.conf` root:root 0600 written by
`cloudpex/install.sh` prompts (HOST, SHARE, SMB_USER, MNT, SMB_VERS; regex-validated, re-ask on bad input so
main install.sh never aborts; keep-existing [Y/n]; skipped without TTY). Script parses lines
(`sed -n s/^KEY=//p`), never sources → no code exec as root from config. Alt rejected: sed placeholders into
deployed script — config + code mixed, every re-run overwrites values. Status: done in repo.

## BDR-013 — security baseline always-on in install.sh: fail2ban (all-ports), unattended-upgrades, sshd limits
2026-09-22. User: "fail2ban and the like, systematically". Chose no-prompt Linux-block steps: (1) fail2ban sshd
jail `backend = systemd` + `banaction = %(banaction_allports)s` → SSH port irrelevant (old server banned 22 while
sshd on 337, LRN-012); `ignoreip` = loopback + RFC1918 static (no LAN detection; trade-off: compromised LAN host
never banned); 5/10m/1h from RECOVERY doc 01. (2) `20auto-upgrades` file instead of interactive dpkg-reconfigure.
(3) sshd drop-in limited to PermitRootLogin/MaxAuthTries/LoginGraceTime, `sshd -t` gated, rejected file removed +
install continues. Declined by user: auditd rules, ufw whitelist (site-specific ports, lockout risk → would be an
offer, not systematic). Not included by design: PasswordAuthentication no / AllowUsers / X11Forwarding no
(lockout or workflow risk). Status: done in repo (feature/security-baseline), live apply = user.

## BDR-014 — install.sh mirrors machine apt set: GNOME + LAMP unconditional, NVIDIA via ubuntu-drivers
2026-09-28. Source: `apt-mark showmanual` + /var/log/apt/history.log diffed vs script. Added gitleaks, web stack
(mariadb-server imagemagick php-* unversioned → follows distro PHP), ubuntu-desktop-minimal before RDP setup
(gnome-remote-desktop needs GDM, bare server had none), `install_nvidia_driver()` = `lspci -d 10de:` gate +
`ubuntu-drivers install` (distro-recommended, 595-open today). Alternatives rejected: pin nvidia-driver-595-open
(ages, hardware-bound), LAMP behind confirm() offer (user: base list), GNOME left implicit (RDP fails silently).
Status: merged to develop. Live rerun of install.sh = user.

## BDR-015 — macOS: Homebrew replaces apt, Docker via colima, login shell bash 5 OR zsh (user choice)
2026-10-05. install.sh Darwin branch: ensure_homebrew (official script if missing) → brew update/upgrade → apt list
mapped to formulae. Docker = colima + docker/compose/buildx CLI (`cliPluginsExtraDirs` written only if
~/.docker/config.json absent). colima/code-server/mariadb = `brew services` (skip if started). Shell asked first
(`MACOS_SHELL` presets, no TTY → bash): bash → brew bash 5 in /etc/shells + chsh (macOS bash 3.2 too old: no
EPOCHREALTIME, HISTSIZE=-1); zsh → oh-my-zsh unattended + zsh/zshrc-osx + bchanot.zsh-theme (bash prompt port), chsh
/bin/zsh. End: print_macos_gaps lists Linux-only items skipped. Alts rejected: Docker Desktop (GUI, licence), no
Docker; staying on zsh w/o config. Status: merged develop 7d5dabd.

## BDR-016 — ~/.zshrc backed up to ~/.zshrc.backup-<date>, not ~/Oldconfig
2026-10-05. ~/Oldconfig is `rm -rf` at every run → 2nd run destroys 1st-run backup of user's real zshrc (nvm, bun
lines). deploy_zsh_config: if ~/.zshrc differs from repo copy (cmp -s) → timestamped mv in $HOME; identical → no
backup (rerun no dup). Machine-specific lines → ~/.zshrc.local (sourced). Same flaw still on .bashrc/.vim (open,
not fixed). Status: done.

## BDR-017 — tmux pane moves on ctrl+u/h/j/k, not hjkl nor option+arrows
2026-10-06. u/h/j/k laid out as arrows (u up, h left, j down, k right): same key positions on AZERTY and QWERTY US,
control exists on every keyboard (option does not, cmd never reaches tmux). Alternatives rejected: ctrl+i/j/k/m
(C-i = Tab, C-m = Enter, same bytes, would break completion); option+arrows (needs iTerm2 "Left Option = Esc+",
no option key on some keyboards). Cost: shell loses C-u (readline clear-line). Gain: C-l free, clears screen again.
Resize mirrors it with prefix. Status: done (tmux.conf).

## BDR-018 — Linux tmux clipboard = tmux buffer + OSC 52, no xsel/xclip
2026-10-06. tmux.conf clipboard via `if-shell 'command -v pbcopy'`: macOS → pbcopy/pbpaste; else `y` =
copy-selection-and-cancel, `p` = paste-buffer, tmux hands the buffer to the terminal through OSC 52 (set-clipboard),
reaches the local clipboard over ssh from iTerm2. xsel/xclip rejected: headless servers have no X display (xsel
errors), xclip keeps STDOUT open and hangs tmux. Status: done.

## BDR-019 — gitflow.autopush at install: sed read of ~/.gitconfig, exact true/false, bad preset aborts
2026-10-07. Need: install asks push mode, renders `[gitflow] autopush` in gitconfig template. Chosen: existing
value read with `sed` on `~/.gitconfig` (same shape as rc_export_value), reused only if exactly `true`/`false`;
`DOTFILES_GITFLOW_AUTOPUSH` validated first, non-boolean → `return 1` → install aborts before any file touched;
prompt re-asks until exact, Enter = true; no tty = true. `render_gitconfig` refuses non-boolean / leaked
`@AUTOPUSH@`. Fixed `core.hooksPath = ~/.claude/githooks` in template (git expands `~`, `make link` owns dir).
Rejected: `git config --bool` read (that command family denied to Claude session → oracle could not run; also
XDG/system scopes not needed, installer writes ~/.gitconfig only); git boolean grammar / fr words (fail-open on
"non", user wants strict). Deviation from BDR-012 "never abort": bad preset aborts, user's fail-closed call.
Status: merged develop e4cf818.

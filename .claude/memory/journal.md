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

## 2026-09-22 — /tmp on disk + SSH OOM guard + cloudpex conf
User: swap for /tmp? keep RAM for ssh, old-server rules, cloudpex README+installer. Found /tmp = tmpfs 50% RAM
→ swap rejected, mask tmp.mount offer (BDR-010). Old rules in NAS RECOVERY/40-systeme: ssh drop-in + earlyoom →
end-of-install offers (BDR-011). cloudpex tracked; site values → /etc/cloudpex.conf prompted by installer
(BDR-012). shellcheck/bash -n CLEAN, stub harnesses (LRN-011; EVAL-002 open until live apply). Reconciled
main→develop (a210d01 dtach was main-only), feature finished via lib → develop 836bb67. Not applied live.
Flagged: secrets in NAS transfert/root (BLK-005), remote-install.sh BRANCH=master stale vs main, gitea-deploy/
untracked, remote feature branch left on origin (lib deletes local only).
Later same day: security baseline always-on in install.sh (fail2ban all-ports + RFC1918 ignore, unattended-
upgrades file, sshd limits drop-in sshd -t gated) on feature/security-baseline (BDR-013, LRN-012: old jail
banned 22 not 337). auditd + ufw declined. shellcheck/bash -n CLEAN, stub harness incl. sshd -t reject path,
configparser + apt-config checks. Branch pushed, NOT finished (no merge signal). Live apply = user runbook.
Update: user said merge → feature/security-baseline finished via lib, develop a6c416e pushed.
Cleanup: user asked all-in-develop + delete branches. Hooks refresh committed (a42e8f6). All 3 remote feature
branches verified merged; `git push --delete` DENIED by permission layer → user runs it. gitea-deploy/ (untracked
Gitea server deploy project, 31 files, no secrets) moved to ~/Documents/gitea-deploy, own repo via gitflow init,
pushed main+develop to git.bchanot.fr (push-to-create worked). deploy.conf gitignored.

## 2026-09-28
- feature/apt-packages (0bc9e3f, unmerged): install.sh mirrors machine apt set. Diff `apt-mark showmanual` +
apt history vs script → added gitleaks, web stack (mariadb-server imagemagick php-* unversioned),
ubuntu-desktop-minimal before RDP, install_nvidia_driver() (lspci 10de gate, `ubuntu-drivers install`, no pin).
User approved 3 choices (GNOME in, ubuntu-drivers, LAMP unconditional). shellcheck + bash -n + stub run OK.
- Blocked mid-commit: lib pre-commit ran `gitleaks git --staged`, Ubuntu apt gitleaks = 8.16 (no `git` subcmd,
exit 1 read as leak). Fixed in claude-config bugfix/gitleaks-protect-fallback (347073a, unmerged): probe
`gitleaks git --help`, fallback `protect --staged`; T16c symlink-farm PATH. make test 0. Hooks refreshed here (9e49b9d).
- Note: `gh` in install.sh list but not installed on this box (script not rerun since added).

## 2026-10-05 — macOS support + zsh/bash choice
Local main 15 commits behind develop → worked off develop. install.sh Darwin branch (Homebrew, colima, brew services,
gaps report), bashrc-osx = bashrc-linux + macOS deltas, dt portable, zsh option (oh-my-zsh + bchanot theme). Tested:
shellcheck, bash 3.2/5 + zsh -n, bashrc/zshrc/theme live in shells, dt with real dtach session, stub harness both
choices. Full install.sh not run on this Mac. BDR-015/016, LRN-014, BLK-007. Merged develop 7d5dabd, not pushed.

## 2026-10-06
- Cut v1.0.0: first tagged release, develop → main via /release-candidate. CHANGELOG.md bootstrapped from 31 develop commits, version.txt created. Tag pushed. Pre-existing shellcheck SC2148 on bashrc files untouched.

## 2026-10-06 (pm) — macOS tmux config + cloudpex offer
Done: tmux.conf (sohorx vi-style, tpm) deployed on macOS → ~/.config/tmux, tpm cloned + plugins fetched headless, libtmux via pip --user (PEP 668 fallback). XDG_CACHE_HOME exported in osx rc files (config needs it, else resurrect dir = "/tmux/"). cloudpex: unconditional install → [y/N] offer with the other Linux extras. Verified: shellcheck, temp-HOME run x3, tmux parses config. Branch feature/tmux-config → develop.

## 2026-10-06 (pm, 2) — tmux keys + Linux
Done: tmux.conf fixes (pbcopy, C-a passthrough, is_vim via pane_current_command), pane moves ctrl+u/h/j/k (AZERTY/QWERTY invariant; C-i/C-m = Tab/Enter, rejected), splits prefix i / -, deploy on Linux too (clipboard if-shell: pbcopy else tmux buffer + OSC 52). Verified in Ubuntu 24.04 container. Merged bugfix/tmux-macos-keys → develop (e3be25f).

## 2026-10-06 (pm, 3) — tmux selection, keep tmux over iTerm2 splits
Done: mode-style yellow/black (black bg invisible on dark iTerm2), mouse drag release copies (pbcopy / tmux buffer) without leaving copy-mode. Merged bugfix/tmux-selection → develop (b73ee08). Decided (chat, AskUserQuestion): keep tmux, not iTerm2/Terminator/WezTerm splits — ssh persistence, GNOME Terminal has no splits. BDR offered, not written yet. Wheel issue was a stale iTerm2 session: restart fixed it.

## 2026-10-06 (pm, 4) — tmux click exit + alt copy/paste
Done: plain click leaves copy-mode (MouseUp1Pane cancel; MouseDown cancel was wrong, killed drag after scroll), alt+c = y, alt+v = paste, per OS. Merged bugfix/tmux-click-exit → develop (8b5e936). Open: iTerm2 "Left Option = Esc+" is manual (US Intl PC layout coming); dynamic-profile deploy offered, not asked. GNOME Terminal OSC 52 support unverified.

## 2026-10-06 (pm, 5) — identity asked at install
Done: USER/EMAIL no longer hardcoded in tracked rc files (@USER@/@EMAIL@ placeholders, rendered by install.sh; existing rc export reused, else IDENTITY_* env, else prompt). vimrc reads $USER/$EMAIL. Merged feature/identity-prompt → develop (0687f6a). Open: old values remain in git history (rewrite not done, destructive); deployed ~/.bashrc/.zshrc on this Mac still hold bchanot@gmail.fr.

## 2026-10-06 — tmux wheel halved, dtach mac/termux checked
Done: copy-mode-vi WheelUp/DownPane rebound `-N 2` (stock 5), live reload OK. Merged bugfix/tmux-wheel-half → develop (ec9d0ed). Checked: dtach master on macOS reparents to launchd, survives parent SIGKILL + SIGHUP (sessions outlive shell crash). Termux: dtach 0.9 in official repo, scripts need `pkg install dtach fzf procps`; install.sh NOT Termux-safe (apt-get path); app kill = sessions lost, needs termux-wake-lock. Untested on device.

## 2026-10-06 (pm, 7) — tmux ctrl+h/j/k/u in copy-mode
Done: copy-mode-vi table had stock C-h cursor-left, C-u halfpage-up, C-j copy, so no-prefix pane moves became text nav once scrolled. Four keys rebound select-pane in copy-mode-vi, live reload OK. Merged bugfix/tmux-copy-mode-ctrl-nav → develop (8b6ed6b). Open: deployed ~/.config/tmux/tmux.conf on this Mac predates alt+v/wheel/this fix, `./install.sh` not re-run.

## 2026-10-06 (pm, 8) — tmux drag "syntax error" in claude panes
Done: MouseDrag1Pane binding had `\"` inside '...' (literal since tmux 3.0); branch for mouse-tracking panes (claude fullscreen, vim mouse=a) failed to parse → "syntax error", no selection. Backslashes dropped, pitfall noted in conf. Deployed to ~/.config/tmux/tmux.conf + source-file, live binding verified (`forwarded-to-app`). Merged bugfix/tmux-drag-syntax-error → develop (2245247). Closes the "deployed conf stale" open item.

## 2026-10-07 — tmux dim inactive panes
Done: window-style / window-active-style added. Two traps: colour234 ≈ iTerm2 dark bg (#15191f) → invisible; `window-active-style bg=default` inherits window-style since tmux 3 → active pane dimmed too, terminal colours hardcoded instead (fg #dcdcdc, bg #15191f). Inactive settled at #353d48 / #a6acb6 after 3 live rounds. Light macOS theme would need the inverse. Merged feature/tmux-dim-inactive-panes → develop.

## 2026-10-07 (pm) — repo-sync: multi-forge repo tree
Done: `bin/repo-sync` (gitlab/github/gitea/bitbucket cloud via curl+jq, daily cache, mkdir lock, dedup ns/project) + `repo` fn/completion in 3 rc files + install.sh jq + docs. Port of Alphalink dotfiles `repo`/`repo-reset`. Stub-curl harness caught token shift (IFS tab merges empty field); live GitLab 139 projects in 3s. Decided (chat): name `repo-sync`, tokens in `~/.config/repos/forges.conf` 0600, root `~/repos`, Bitbucket Cloud only. On feature/repo-sync, not finished. BDR/LRN offered, not written.

## 2026-10-07 (2) — macOS zsh default, remote-install prompts
Done: choose_macos_shell default bash → zsh (Enter, no tty, unknown value). Found: `curl | bash` path never asked USER/EMAIL (stdin = pipe → `[ -t 0 ]` false → login name + empty email, bash, no offers); remote-install.sh now runs install.sh `</dev/tty` when openable. Found: BRANCH default `master`, origin has only `main` (raw URL 404) → `main`. Lint OK, chooser tested 4 values. Branch feature/macos-zsh-default, not merged. Other session: feature/repo-sync open (CLAUDE.md layout already lists repo-sync).

## 2026-10-07 (3) — gitflow.autopush asked at install, hooksPath fixed, identity bug
Done: `gitconfig` template `[gitflow] autopush = @AUTOPUSH@` + fixed `core.hooksPath = ~/.claude/githooks`; install.sh `resolve_autopush` (existing ~/.gitconfig value via sed → `DOTFILES_GITFLOW_AUTOPUSH` strict, bad value aborts → prompt re-asks exact true/false, Enter = true → true), `render_gitconfig` fail-closed (non-boolean / leaked placeholder = nothing written). Found by challenge: install.sh:688 passed the repo bashrc TEMPLATE to deploy_gitconfig → every install wrote `name = @USER@`; fixed, identity passed directly. `shopt -u patsub_replacement` (bash ≥ 5.2 `&` in names). Oracle harness `.claude/tasks/contracts/check-autopush-render.sh` (12 cases, scratch HOMEs, zero `git config`: that command family is denied to the session). 3 challengers + 1 confirm, verifier ECARTS(1) → CONFORME, security PASS (MEDIUM noted: newline in IDENTITY_* env injects gitconfig lines, pre-existing for rc too). Code commit 9901ec5 on feature/gitconfig-autopush; merge on user signal.

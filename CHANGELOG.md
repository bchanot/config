# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: semver.

## [Unreleased]

### Added
- `install.sh` asks the gitflow push mode (`gitflow.autopush`, exactly `true` or `false`, Enter = `true`) and writes it to `~/.gitconfig`; an existing value is reused, `DOTFILES_GITFLOW_AUTOPUSH` presets it, any other preset aborts the install.
- `gitconfig`: fixed `core.hooksPath = ~/.claude/githooks`.
- `tmux.conf`: move panes between windows — `J`/`L` join the marked pane below/beside, `S` swaps it with the current one, `(`/`)` (repeatable) move the pane to the previous/next slot.
- `tmux.conf`: window tabs centred in the status bar (`absolute-centre`), with index, padding and a blank between tabs; the current tab bold on a light pill.
- `bin/tmux-copy-exit-keys` + `tmux.conf`: after a mouse selection any bare key leaves copy-mode and returns to the prompt (key swallowed); ctrl/alt keys, and copy-mode opened from the keyboard or the wheel, keep their vi role.
- `tmux.conf`: Alt+Left/Right switch windows without the prefix (macOS: map Cmd+arrow in iTerm2 to the `[1;3D` / `[1;3C` escape sequences).

### Changed
- `.githooks/post-commit` and `post-merge` fail closed on `gitflow.autopush`: an unreadable or non-boolean value means no push, with a named warning (was: silently treated as `true`).

### Fixed
- `~/.gitconfig` was deployed with the literal `@USER@` / `@EMAIL@` placeholders: the installer read the identity from the repo bashrc template instead of the answers.
- An `&` in the name no longer corrupts the rendered identity on bash 5.2 and later (`patsub_replacement` turned off).

## [1.0.0] — 2026-10-06

### Added
- macOS support in `install.sh`: Homebrew instead of apt, colima for Docker,
  brew services for code-server/mariadb, bash or zsh login shell choice
  (`MACOS_SHELL`), report of the Linux-only items skipped.
- `bash/bashrc-osx`: `bashrc-linux` mirrored with the macOS deltas (brew env,
  `ls -G`, `EPOCHREALTIME` timer, `cc` without systemd-run).
- `zsh/zshrc-osx` + `zsh/bchanot.zsh-theme`: oh-my-zsh config and theme
  porting the bash prompt.
- `gitconfig` template deployed as user-scope `~/.gitconfig`, `@USER@` /
  `@EMAIL@` filled at install; a differing file is kept as
  `~/.gitconfig.backup-<date>`.
- `git-delta` in the apt and brew package lists (the gitconfig pager).
- Security baseline on Linux, always applied and idempotent: fail2ban sshd
  jail (journal backend, all-ports ban, LAN ignored), unattended security
  upgrades, sshd hardening drop-in gated by `sshd -t`.
- End-of-install offers on Linux: `/tmp` on disk (mask `tmp.mount` +
  tmpfiles rules) and SSH memory guard (sshd OOM-exempt drop-in + earlyoom).
- `cloudpex/`: on-demand SMB mount helper, installer and FR README; site
  values prompted at install into `/etc/cloudpex.conf`, never in the script.
- Apt package list mirroring the reference machine: gitleaks, web stack,
  `ubuntu-desktop-minimal`, lspci-gated NVIDIA driver install, `gh`.

### Changed
- Shell identity exported as `USER` / `EMAIL` instead of `VIUSER` / `VIMAIL`
  in every rc file; the installer takes the login name from `id -un`.
- `install.sh` uses `cp -Rpv` (BSD-compatible).

### Fixed
- `bin/dt` macOS portability: `lsof` cwd, BSD `date` start time, bash 3.2
  tilde expansion, `sed -E` help.

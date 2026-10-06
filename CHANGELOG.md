# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: semver.

## [Unreleased]

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

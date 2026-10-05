# config

Personal dotfiles — vim + bash configuration and a one-shot installer.

## Quick start

Install everything (clone + setup) with one command:

```sh
curl -fsSL https://git.bchanot.fr/bchanot/config/raw/branch/master/remote-install.sh | bash
```

(Runs a remote script through `bash` — see the [Install](#install) section for what it does and the manual alternative.)

## What's inside

| Path                 | Purpose                                                        |
| -------------------- | -------------------------------------------------------------- |
| `install.sh`         | Linux: installs apt packages + Docker + code-server + RDP (gnome-remote-desktop), backs up old config, deploys vim + bashrc (OS-detected), installs CLI scripts, pipx tools, a low-disk login warning and the `cloudpex` NAS mount helper; ends by offering two system changes (`/tmp` on disk, SSH memory guard). macOS: same tooling through Homebrew (see [macOS](#macos)), then prints what was not installed compared with Linux. |
| `cloudpex/`          | On-demand SMB mount of a NAS share (`cloudpex` command + its installer). Site values (host, share, SMB user, mount point, SMB version) are prompted at install and stored in `/etc/cloudpex.conf`, never in the script. French README inside. |
| `etc/tmpfiles.d/tmp.conf` | Cleanup rules for a disk-backed `/tmp` (wiped at boot, 10-day purge). Deployed by the `/tmp` on disk offer. |
| `etc/systemd/ssh.service.d/override.conf` | `ssh.service` drop-in: sshd exempt from the OOM killer + memory reclaim protection. Deployed by the SSH memory guard offer. |
| `etc/default/earlyoom` | earlyoom arguments: spare sshd/systemd, kill node/java first. Deployed by the SSH memory guard offer. |
| `etc/fail2ban/jail.d/local.conf` | fail2ban sshd jail: journal backend, all-ports ban, 5 tries / 10 min / 1 h, private LAN never banned. Deployed on every Linux install. |
| `etc/apt/apt.conf.d/20auto-upgrades` | Enables unattended security upgrades (what `dpkg-reconfigure` writes). Deployed on every Linux install. |
| `etc/ssh/sshd_config.d/20-hardening.conf` | sshd limits that cannot lock you out: `PermitRootLogin no`, `MaxAuthTries 3`, `LoginGraceTime 20`. Deployed on every Linux install after `sshd -t`. |
| `vim/vimrc`          | Vim config: pathogen, molokai, syntastic (C with `-Wall -Werror -Wextra`), NERDTree, 42-style canonical class generators (`:ClassH`, `:ClassC`). |
| `vim/autoload/`      | `pathogen.vim` plugin loader (committed).                      |
| `vim/colors/`        | `molokai.vim` colorscheme (committed).                         |
| `bash/bashrc-linux`  | bashrc for desktop Linux (git-aware prompt + command timer).   |
| `bash/bashrc-osx`    | bashrc for macOS: `bashrc-linux` adapted (Homebrew on `PATH`, BSD `ls -G`, bash 5 clock for the timer, `cc` without `systemd-run`). |
| `zsh/zshrc-osx`      | zshrc for macOS when zsh is chosen: oh-my-zsh + the same env, aliases and dtach menu as `bashrc-osx`. Loads `~/.zshrc.local` for machine-specific lines. |
| `zsh/bchanot.zsh-theme` | oh-my-zsh theme reproducing the bash prompt: `✔ (12ms) user [ ~/dir ] [branch -*+] >`. |
| `bin/dt`             | dtach session manager for claude-in-dtach sessions.            |
| `bin/dtach-router`   | Dashboard to resume dtach sessions, shown at the start of every interactive shell (wired into `~/.bashrc` by the installer). |
| `bin/claude-provider`| Switch Claude Code between Anthropic and OpenRouter.           |
| `etc/profile.d/disk-usage-warning.sh` | Login-time warning (bold red) when `/` or `/home` cross 85% usage. Deployed to `/etc/profile.d/` on Linux. |

## Install

### One-liner (clone + install)

```sh
curl -fsSL https://git.bchanot.fr/bchanot/config/raw/branch/master/remote-install.sh | bash
```

`remote-install.sh` ensures `git` is present, clones the repo to `~/config` (or pulls if already there), then runs `install.sh`. Override with env vars: `REPO_URL=... CLONE_DIR=... BRANCH=... curl ... | bash`.

> Piping a remote script into `bash` runs unreviewed code over the network. Read [`remote-install.sh`](remote-install.sh) first, or use the manual clone below.

### Manual

```sh
git clone https://git.bchanot.fr/bchanot/config.git && cd config
./install.sh
```

No argument — the OS is auto-detected.

What it does:

1. On Debian/Ubuntu, installs a set of CLI/dev packages via `apt-get` (see below). On macOS, Homebrew does it instead: see [macOS](#macos).
2. Sets up Docker's official apt repo (Ubuntu) and installs the engine + compose plugin — skipped if `docker` is already present.
3. Moves any existing `~/.vim`, `~/.vimrc`, `~/.bashrc`, `~/.Sublivim` to `~/Oldconfig`.
4. Clones the `syntastic` and `nerdtree` vim plugins into `~/.vim/bundle/`.
5. Copies the tracked vim files into `~/.vim` and symlinks `~/.vimrc`.
6. Picks the bashrc by OS: macOS → `bashrc-osx` (falls back to `bashrc-linux` if missing), everything else → `bashrc-linux`. Copies it to `~/.bashrc`.
7. Installs Python CLIs via `pipx` (`PyMuPDF` → `pymupdf`, `Markdown` → `markdown_py`) — skipped if `pipx` is absent.
8. Copies the `bin/` scripts (`dt`, `dtach-router`, `claude-provider`) into `~/.local/bin`. The dtach session-resume menu ships in the deployed bashrc (both OSes), so every interactive shell offers it — including VS Code Remote-SSH terminals, which are non-login and never read `~/.profile`. The installer also strips any older dtach block left in `~/.profile` so a plain SSH login doesn't prompt twice.
9. On Linux, installs `etc/profile.d/disk-usage-warning.sh` to `/etc/profile.d/` (needs `sudo`) so each login warns when `/` or `/home` cross 85% usage.
10. On Linux, installs **code-server** (VS Code in the browser) via its vendor script — skipped if already present — and enables the `code-server@$USER` systemd service.
11. On Linux, installs **`ubuntu-desktop-minimal`** (GDM + GNOME Shell, ~1.5 GB): the RDP remote login below hands out a GNOME session, which a bare server install does not have. Then sets up **RDP remote login** via `gnome-remote-desktop` (Wayland-native): installs the daemon + `openssl`, generates a self-signed TLS cert once, and prompts interactively for shared "gate" credentials (skipped when no terminal is attached, or already set). Disables `xrdp` if present; opens UFW port `3389` only when UFW is already active. Finally, when `lspci` sees an NVIDIA GPU, runs `ubuntu-drivers install` to put on the driver the distro recommends for the card (no version pinned; loads at the next reboot). Skipped on machines without an NVIDIA GPU.
12. On Linux, installs the **`cloudpex`** NAS mount helper to `/usr/local/bin` via `cloudpex/install.sh`, which prompts for the NAS host, share name, SMB user, mount point and SMB version and writes them to `/etc/cloudpex.conf` (root, `0600`; an existing config is shown and kept unless you say `n`; skipped when no terminal is attached). Nothing is mounted, no password stored, see [`cloudpex/README.md`](cloudpex/README.md).
13. On Linux, installs the **security baseline**, always, no prompt: **fail2ban** (+ `nftables`) with `etc/fail2ban/jail.d/local.conf` (sshd jail reading the journal, bans the offending IP on every port so the SSH port does not matter, 5 failures in 10 min → 1 h ban, loopback and private LAN ranges never banned); **unattended-upgrades** enabled through `etc/apt/apt.conf.d/20auto-upgrades`; and the **sshd drop-in** `etc/ssh/sshd_config.d/20-hardening.conf` (`PermitRootLogin no`, `MaxAuthTries 3`, `LoginGraceTime 20`), checked with `sshd -t` and removed again if sshd rejects it, then `reload ssh`. Authentication methods, port and user lists are left as they are.
14. On Linux, at the very end, **offers** (`[y/N]`, skipped when no terminal is attached) to move **`/tmp` to disk**: Ubuntu mounts `/tmp` as a RAM-backed tmpfs capped at 50% of RAM, which agent runs fill, halving the RAM and breaking every shell with "No space left on device". Accepting masks `tmp.mount` and installs `etc/tmpfiles.d/tmp.conf` (wipe at boot, 10-day purge). Effective at the next reboot.
15. On Linux, at the very end, **offers** to keep **SSH reachable under memory pressure**: installs the `ssh.service` drop-in (`OOMScoreAdjust=-1000`, `MemoryMin=256M`) and `earlyoom` with `etc/default/earlyoom` (kills the largest process, `node`/`java` first and never `sshd`, once free RAM and swap both drop under 10%). Restarting `ssh` keeps open sessions. Note: `MemoryMin` protects the sshd daemon only; login sessions live in `user.slice`, so no setting can reserve RAM for a future shell. earlyoom acting in time is the real protection.

### Packages installed (apt)

- **Build / VCS / C dev**: `vim git git-lfs git-filter-repo gitleaks gcc make pkg-config dkms valgrind shellcheck gh`
- **Net / security / transport**: `curl gnupg ca-certificates apt-transport-https net-tools openssh-server cifs-utils lftp ftp`
- **Shell tooling**: `unzip tree tmux fzf dtach`
- **Runtimes**: `nodejs python3-pip pipx php-cli`
- **Web stack (local WordPress/LAMP)**: `mariadb-server imagemagick php-mysql php-gd php-imagick php-mbstring php-xml php-intl php-curl` (unversioned `php-*` metapackages, so they follow the distro's PHP)
- **Media / doc CLI**: `ffmpeg weasyprint poppler-utils qpdf webp libavif-bin`
- **Docker**: `docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin` (via Docker's repo)
- **Desktop / GPU**: `ubuntu-desktop-minimal` (always, Linux) + the distro-recommended NVIDIA driver via `ubuntu-drivers install` (only when an NVIDIA GPU is detected)
- **Remote access**: `gnome-remote-desktop openssl` (apt) + `code-server` (via its vendor install script, not apt) — RDP remote login + browser VS Code
- **pipx**: `PyMuPDF` (`pymupdf`), `Markdown` (`markdown_py`)
- **Security baseline (Linux, always)**: `fail2ban nftables unattended-upgrades`
- **Optional (end-of-install offer, Linux)**: `earlyoom`

The script is re-runnable: each run re-backs up to `~/Oldconfig` (overwriting the previous backup), re-clones plugins, skips Docker if already installed, and re-deploys the `bin/` scripts.

> Note: the Docker repo step assumes **Ubuntu**.

### macOS

The same `./install.sh` detects macOS and replaces `apt-get` with Homebrew. It first asks which login shell you want, **bash** or **zsh** (`[bash]` by default; answer in advance with `MACOS_SHELL=zsh ./install.sh`, and with no terminal attached it picks bash):

1. Installs Homebrew with its official script when `brew` is missing (this also pulls the Xcode Command Line Tools: clang, make, git), then `brew update` + `brew upgrade`.
2. Installs the apt list mapped to formulae: `vim git git-lfs git-filter-repo gitleaks pkgconf shellcheck gh curl gnupg lftp inetutils unzip tree tmux fzf dtach node python pipx php mariadb imagemagick ffmpeg weasyprint poppler qpdf webp libavif bash`. Brew's `php` already ships gd, mbstring, xml, intl, curl and mysql.
3. Docker: `colima` (the Linux VM) + `docker docker-compose docker-buildx`. Writes `~/.docker/config.json` with `cliPluginsExtraDirs` so `docker compose` works, only when that file does not exist yet (otherwise prints the line to add).
4. Starts `colima`, `code-server` and `mariadb` as `brew services` (the `systemctl enable --now` equivalent), skipping any already started.
5. Deploys `bashrc-osx`, then appends one line to `~/.bash_profile` that sources `~/.bashrc`: macOS terminals open login shells, which never read `~/.bashrc` on their own. Done for both choices, so `bash` stays usable.
6. **bash** chosen: makes brew's bash 5 the login shell (adds it to `/etc/shells` with `sudo`, then `chsh`, which asks for your password). macOS ships bash 3.2, too old for the bashrc.
   **zsh** chosen: installs oh-my-zsh with its official script (unattended, skipped if `~/.oh-my-zsh` exists), deploys `zsh/zshrc-osx` to `~/.zshrc` and the `bchanot` theme to `~/.oh-my-zsh/custom/themes/`, then makes `/bin/zsh` the login shell. An existing `~/.zshrc` that differs from the repo's is saved as `~/.zshrc.backup-<date>` (outside `~/Oldconfig`, which every run wipes). Move your machine-specific lines (nvm, bun, tokens) into `~/.zshrc.local`: the deployed zshrc loads it.
7. Ends with the list of what the Linux install has and this one does not: `gcc` (Apple clang answers to `gcc`), `valgrind`, `dkms`, `net-tools`, `openssh-server` and the RDP desktop (both built into macOS, switched on in System Settings > Sharing), `cifs-utils`, `php-imagick`, the NVIDIA driver, the disk-usage warning, `cloudpex`, the security baseline and the two end-of-install offers.

### CLI scripts (`bin/`)

Deployed to `~/.local/bin` (the deployed bashrc adds this dir to `PATH`):

- **`dt`** — manage claude-in-dtach sessions (`dt ls|at|kill`). Needs `dtach` + `fzf`.
- **`dtach-router`** — session dashboard shown at shell startup. It ships in the deployed bashrc and is **sourced** (not executed) in every interactive shell, so it also fires in VS Code Remote-SSH terminals (non-login shells that skip `~/.profile`). Silent no-op when no session exists. Create a session with `cc [name]`, re-open the menu anytime with `d` (both aliases from the bashrc). Needs `dt`, `dtach`, `fzf`.
- **`claude-provider`** — switch Claude Code between Anthropic and OpenRouter.
  OpenRouter mode reads the key from **`$OPENROUTER_API_KEY`** (never hardcoded). Export it from a private, untracked file, e.g. `~/.bashrc.local`:
  ```sh
  export OPENROUTER_API_KEY="<your-openrouter-key>"
  ```

## Requirements

- `bash`, `git`
- Debian/Ubuntu `apt-get`, or macOS (Homebrew is installed if missing)
- A `bash` login shell on Linux (zsh users switch to bash for these prompts to apply). On macOS the installer sets bash or zsh, your choice

## License

GPL-3.0-or-later — see [LICENSE](LICENSE).

Copyright (C) 2026 Bastien Chanot.

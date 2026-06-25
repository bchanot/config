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
| `install.sh`         | Installs apt packages + Docker + code-server + RDP (gnome-remote-desktop), backs up old config, deploys vim + bashrc (OS-detected), installs CLI scripts, pipx tools, and a low-disk login warning. |
| `vim/vimrc`          | Vim config: pathogen, molokai, syntastic (C with `-Wall -Werror -Wextra`), NERDTree, 42-style canonical class generators (`:ClassH`, `:ClassC`). |
| `vim/autoload/`      | `pathogen.vim` plugin loader (committed).                      |
| `vim/colors/`        | `molokai.vim` colorscheme (committed).                         |
| `bash/bashrc-linux`  | bashrc for desktop Linux (git-aware prompt + command timer).   |
| `bash/bashrc-osx`    | bashrc for macOS.                                              |
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

1. On Debian/Ubuntu, installs a set of CLI/dev packages via `apt-get` (see below). Skipped automatically where `apt-get` is absent (macOS).
2. Sets up Docker's official apt repo (Ubuntu) and installs the engine + compose plugin — skipped if `docker` is already present.
3. Moves any existing `~/.vim`, `~/.vimrc`, `~/.bashrc`, `~/.Sublivim` to `~/Oldconfig`.
4. Clones the `syntastic` and `nerdtree` vim plugins into `~/.vim/bundle/`.
5. Copies the tracked vim files into `~/.vim` and symlinks `~/.vimrc`.
6. Picks the bashrc by OS: macOS → `bashrc-osx` (falls back to `bashrc-linux` if missing), everything else → `bashrc-linux`. Copies it to `~/.bashrc`.
7. Installs Python CLIs via `pipx` (`PyMuPDF` → `pymupdf`, `Markdown` → `markdown_py`) — skipped if `pipx` is absent.
8. Copies the `bin/` scripts (`dt`, `dtach-router`, `claude-provider`) into `~/.local/bin`. The dtach session-resume menu ships in the deployed `bashrc-linux`, so every interactive shell offers it — including VS Code Remote-SSH terminals, which are non-login and never read `~/.profile`. The installer also strips any older dtach block left in `~/.profile` so a plain SSH login doesn't prompt twice.
9. On Linux, installs `etc/profile.d/disk-usage-warning.sh` to `/etc/profile.d/` (needs `sudo`) so each login warns when `/` or `/home` cross 85% usage.
10. On Linux, installs **code-server** (VS Code in the browser) via its vendor script — skipped if already present — and enables the `code-server@$USER` systemd service.
11. On Linux, sets up **RDP remote login** via `gnome-remote-desktop` (Wayland-native): installs the daemon + `openssl`, generates a self-signed TLS cert once, and prompts interactively for shared "gate" credentials (skipped when no terminal is attached, or already set). Disables `xrdp` if present; opens UFW port `3389` only when UFW is already active.

### Packages installed (apt)

- **Build / VCS / C dev**: `vim git git-lfs git-filter-repo gcc make pkg-config dkms valgrind shellcheck`
- **Net / security / transport**: `curl gnupg ca-certificates apt-transport-https net-tools openssh-server cifs-utils lftp ftp`
- **Shell tooling**: `unzip tree tmux fzf dtach`
- **Runtimes**: `nodejs python3-pip pipx php-cli`
- **Media / doc CLI**: `ffmpeg weasyprint poppler-utils qpdf webp libavif-bin`
- **Docker**: `docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin` (via Docker's repo)
- **Remote access**: `gnome-remote-desktop openssl` (apt) + `code-server` (via its vendor install script, not apt) — RDP remote login + browser VS Code
- **pipx**: `PyMuPDF` (`pymupdf`), `Markdown` (`markdown_py`)

The script is re-runnable: each run re-backs up to `~/Oldconfig` (overwriting the previous backup), re-clones plugins, skips Docker if already installed, and re-deploys the `bin/` scripts.

> Notes: the package list is Debian/Ubuntu-specific, and the Docker repo step assumes **Ubuntu**. On macOS the whole `apt-get` block is skipped — install `vim`/`git`/toolchain via Homebrew yourself.

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
- Debian/Ubuntu `apt-get` for the package step (optional elsewhere)
- A `bash` login shell (zsh users: switch to bash for these prompts to apply)

## License

GPL-3.0-or-later — see [LICENSE](LICENSE).

Copyright (C) 2026 Bastien Chanot.

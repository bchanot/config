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
| `install.sh`         | Installs apt packages + Docker, backs up old config, deploys vim + bashrc (OS-detected), installs CLI scripts. |
| `vim/vimrc`          | Vim config: pathogen, molokai, syntastic (C with `-Wall -Werror -Wextra`), NERDTree, 42-style canonical class generators (`:ClassH`, `:ClassC`). |
| `vim/autoload/`      | `pathogen.vim` plugin loader (committed).                      |
| `vim/colors/`        | `molokai.vim` colorscheme (committed).                         |
| `bash/bashrc-linux`  | bashrc for desktop Linux (git-aware prompt + command timer).   |
| `bash/bashrc-osx`    | bashrc for macOS.                                              |
| `bin/dt`             | dtach session manager for claude-in-dtach sessions.            |
| `bin/dtach-router`   | SSH-login dashboard to resume dtach sessions (wired into `~/.profile` by the installer). |
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
8. Copies the `bin/` scripts (`dt`, `dtach-router`, `claude-provider`) into `~/.local/bin` and wires the dtach session-resume menu into `~/.profile` (idempotent — sourced only at interactive login, and replaces any prior block).
9. On Linux, installs `etc/profile.d/disk-usage-warning.sh` to `/etc/profile.d/` (needs `sudo`) so each login warns when `/` or `/home` cross 85% usage.

### Packages installed (apt)

- **Build / VCS / C dev**: `vim git git-lfs git-filter-repo gcc make pkg-config dkms valgrind shellcheck`
- **Net / security / transport**: `curl gnupg ca-certificates apt-transport-https net-tools openssh-server cifs-utils lftp ftp`
- **Shell tooling**: `unzip tree tmux fzf dtach`
- **Runtimes**: `nodejs python3-pip pipx php-cli`
- **Media / doc CLI**: `ffmpeg weasyprint poppler-utils qpdf webp libavif-bin`
- **Docker**: `docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin` (via Docker's repo)
- **pipx**: `PyMuPDF` (`pymupdf`), `Markdown` (`markdown_py`)

The script is re-runnable: each run re-backs up to `~/Oldconfig` (overwriting the previous backup), re-clones plugins, skips Docker if already installed, and re-deploys the `bin/` scripts.

> Notes: the package list is Debian/Ubuntu-specific, and the Docker repo step assumes **Ubuntu**. On macOS the whole `apt-get` block is skipped — install `vim`/`git`/toolchain via Homebrew yourself.

### CLI scripts (`bin/`)

Deployed to `~/.local/bin` (the deployed bashrc adds this dir to `PATH`):

- **`dt`** — manage claude-in-dtach sessions (`dt ls|at|kill`). Needs `dtach` + `fzf`.
- **`dtach-router`** — session dashboard on SSH login. The installer wires it into `~/.profile`, where it is **sourced** (not executed) at interactive login and is a silent no-op when no session exists. Create a session with `cc [name]`, re-open the menu anytime with `d` (both aliases from the bashrc). Needs `dt`, `dtach`, `fzf`.
- **`claude-provider`** — switch Claude Code between Anthropic and OpenRouter.
  OpenRouter mode reads the key from **`$OPENROUTER_API_KEY`** (never hardcoded). Export it from a private, untracked file, e.g. `~/.bashrc.local`:
  ```sh
  export OPENROUTER_API_KEY="<your-openrouter-key>"
  ```

## Requirements

- `bash`, `git`
- Debian/Ubuntu `apt-get` for the package step (optional elsewhere)
- A `bash` login shell (zsh users: switch to bash for these prompts to apply)

## Lint

```sh
shellcheck install.sh bash/bashrc-*
```

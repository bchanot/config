# config

Personal dotfiles — vim + bash configuration and a one-shot installer.

## What's inside

| Path                 | Purpose                                                        |
| -------------------- | -------------------------------------------------------------- |
| `install.sh`         | Backs up existing config, then deploys vim + bashrc for a target. |
| `vim/vimrc`          | Vim config: pathogen, molokai, syntastic (C with `-Wall -Werror -Wextra`), NERDTree, 42-style canonical class generators (`:ClassH`, `:ClassC`). |
| `vim/autoload/`      | `pathogen.vim` plugin loader (committed).                      |
| `vim/colors/`        | `molokai.vim` colorscheme (committed).                         |
| `bash/bashrc-linux`  | bashrc for desktop Linux (git-aware prompt + command timer).   |
| `bash/bashrc-osx`    | bashrc for macOS.                                              |

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

1. On Debian/Ubuntu, installs `vim git gcc make pkg-config unzip dkms git-lfs` via `apt-get`. Skipped automatically where `apt-get` is absent (macOS).
2. Moves any existing `~/.vim`, `~/.vimrc`, `~/.bashrc`, `~/.Sublivim` to `~/Oldconfig`.
3. Clones the `syntastic` and `nerdtree` vim plugins into `~/.vim/bundle/`.
4. Copies the tracked vim files into `~/.vim` and symlinks `~/.vimrc`.
5. Picks the bashrc by OS: macOS → `bashrc-osx` (falls back to `bashrc-linux` if missing), everything else → `bashrc-linux`. Copies it to `~/.bashrc`.

The script is re-runnable: each run re-backs up to `~/Oldconfig` (overwriting the previous backup) and re-clones plugins.

> macOS note: the `osx` target skips `apt-get` but still expects `vim`, `git`, and a Homebrew-installed toolchain to be present.

## Requirements

- `bash`, `git`
- Debian/Ubuntu `apt-get` for the package step (optional elsewhere)
- A `bash` login shell (zsh users: switch to bash for these prompts to apply)

## Lint

```sh
shellcheck install.sh bash/bashrc-*
```

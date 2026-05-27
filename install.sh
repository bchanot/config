#!/usr/bin/env bash
# install.sh — deploy the vim + bash dotfiles. OS is auto-detected.
# Usage: ./install.sh
set -euo pipefail

# Resolve the repo root so the script works from any working directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# System packages: Debian/Ubuntu only. Skipped where apt-get is absent (e.g. macOS).
if command -v apt-get >/dev/null 2>&1; then
	sudo apt-get update
	sudo apt-get upgrade -y
	sudo apt-get install -y vim git gcc make pkg-config unzip dkms git-lfs
else
	echo "apt-get not found — skipping system packages (install vim/git manually)."
fi

# Back up any existing config before overwriting (re-runnable).
echo "Backing up existing config to ~/Oldconfig"
rm -rf "$HOME/Oldconfig"
mkdir -p "$HOME/Oldconfig"
for cfg in .vim .Sublivim .vimrc .bashrc; do
	if [ -e "$HOME/$cfg" ]; then
		mv "$HOME/$cfg" "$HOME/Oldconfig/"
	fi
done

# Recreate the vim directory layout.
echo "Creating vim directory structure"
mkdir -p "$HOME"/.vim/{autoload,colors,syntax,plugin,spell,config,bundle}

# Fetch external vim plugins (rm first so re-runs do not fail on existing clones).
echo "Cloning vim plugins"
rm -rf "$HOME/.vim/bundle/syntastic"
git clone --quiet https://github.com/vim-syntastic/syntastic "$HOME/.vim/bundle/syntastic"
rm -rf "$HOME/.vim/bundle/nerdtree"
git clone --quiet https://github.com/preservim/nerdtree "$HOME/.vim/bundle/nerdtree"

# Deploy tracked vim files: vimrc, pathogen loader, molokai colorscheme.
echo "Deploying vim config"
cp -rupv "$SCRIPT_DIR"/vim/* "$HOME/.vim/"
ln -sf "$HOME/.vim/vimrc" "$HOME/.vimrc"

# Deploy the bashrc matching the detected OS.
# macOS uses bashrc-osx (falling back to bashrc-linux if absent); everything else uses bashrc-linux.
if [ "$(uname -s)" = "Darwin" ] && [ -f "$SCRIPT_DIR/bash/bashrc-osx" ]; then
	bashrc="bash/bashrc-osx"
else
	bashrc="bash/bashrc-linux"
fi
echo "Deploying $bashrc"
cp "$SCRIPT_DIR/$bashrc" "$HOME/.bashrc"

echo "Done. Restart your shell or run: source ~/.bashrc"
echo "If you use zsh, switch to bash to enjoy these settings =)"

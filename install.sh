#!/usr/bin/env bash
# install.sh — deploy the vim + bash dotfiles. OS is auto-detected.
# Usage: ./install.sh
set -euo pipefail

# Resolve the repo root so the script works from any working directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Set up Docker's official Ubuntu apt repo, then install the engine + compose plugin.
# Idempotent: skips entirely if docker is already on PATH. Ubuntu-only (uses the ubuntu repo).
install_docker() {
	if command -v docker >/dev/null 2>&1; then
		echo "docker already installed — skipping Docker repo setup"
		return
	fi
	echo "Setting up Docker apt repo"
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc
	local codename arch
	# shellcheck disable=SC1091  # /etc/os-release is sourced at runtime, not available to the linter.
	codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
	arch="$(dpkg --print-architecture)"
	echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" |
		sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# System packages: Debian/Ubuntu only. Skipped where apt-get is absent (e.g. macOS).
if command -v apt-get >/dev/null 2>&1; then
	sudo apt-get update
	sudo apt-get upgrade -y

	# Build + version control + C dev tooling.
	sudo apt-get install -y \
		vim git git-lfs git-filter-repo gcc make pkg-config dkms valgrind shellcheck \
		curl gnupg ca-certificates apt-transport-https \
		unzip tree tmux fzf dtach net-tools \
		openssh-server cifs-utils lftp ftp \
		nodejs python3-pip pipx php-cli \
		ffmpeg wkhtmltopdf poppler-utils qpdf webp libavif-bin

	# Docker (separate repo).
	install_docker
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

# Python CLIs via pipx (run as the user, never sudo). Skipped if pipx is absent.
if command -v pipx >/dev/null 2>&1; then
	echo "Installing pipx CLIs (PyMuPDF -> pymupdf, Markdown -> markdown_py)"
	pipx install PyMuPDF || pipx upgrade PyMuPDF
	pipx install Markdown || pipx upgrade Markdown
	pipx ensurepath >/dev/null
fi

# Deploy personal CLI scripts to ~/.local/bin (dt, dtach-router, claude-provider).
echo "Deploying CLI scripts to ~/.local/bin"
mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR"/bin/* "$HOME/.local/bin/"
chmod +x "$HOME"/.local/bin/dt "$HOME"/.local/bin/dtach-router "$HOME"/.local/bin/claude-provider

echo "Done. Restart your shell or run: source ~/.bashrc"
echo "If you use zsh, switch to bash to enjoy these settings =)"
echo "Note: the deployed bashrc puts ~/.local/bin on PATH — re-login or run: source ~/.bashrc"

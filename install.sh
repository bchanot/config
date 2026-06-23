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

# RDP "gate" credentials: a shared username/password that unlocks the GDM
# login screen (each user then logs into GDM with his own account). Required —
# without it the RDP server rejects every connection (mstsc error 0x904). It is
# a secret, so never stored in this repo: prompted interactively when a terminal
# is attached, otherwise the user is told to set it himself. Idempotent: skipped
# when already configured.
ensure_rdp_credentials() {
	local hint="set later: sudo grdctl --system rdp set-credentials"

	# A non-empty Username means credentials are already configured — nothing to do.
	if ! sudo grdctl --system status 2>/dev/null | grep -q 'Username: (empty)'; then
		return 0
	fi

	if [ ! -t 0 ]; then
		echo "RDP gate credentials not set ($hint)" >&2
		return 0
	fi

	local rdp_user="" rdp_pass=""
	read -rp "RDP gate username: " rdp_user || true
	read -rsp "RDP gate password: " rdp_pass || true
	echo
	if [ -z "$rdp_user" ] || [ -z "$rdp_pass" ]; then
		echo "No credentials entered — $hint" >&2
		return 0
	fi
	sudo grdctl --system rdp set-credentials "$rdp_user" "$rdp_pass"
}

# Remote desktop via gnome-remote-desktop (GNOME's native, Wayland-compatible RDP).
# Mode: system "Remote Login". Two-layer auth: the RDP client first authenticates
# with shared "gate" credentials (set via ensure_rdp_credentials), then the user logs
# into GDM with his own Linux account and a fresh GNOME session starts. xrdp does NOT
# work on this GNOME: it is Wayland-only (GNOME Shell asserts XDG_SESSION_TYPE=wayland,
# which xrdp's Xorg backend cannot satisfy, so the session dies the instant you log in).
# Debian/Ubuntu only. Idempotent.
setup_remote_desktop() {
	local cert="/etc/gnome-remote-desktop/rdp-tls.crt"
	local key="/etc/gnome-remote-desktop/rdp-tls.key"

	# xrdp and gnome-remote-desktop both bind port 3389 — disable xrdp if present.
	if systemctl list-unit-files 2>/dev/null | grep -q '^xrdp\.service'; then
		sudo systemctl disable --now xrdp xrdp-sesman 2>/dev/null || true
	fi

	sudo apt-get install -y gnome-remote-desktop openssl

	# Self-signed TLS cert for the RDP server, generated once so the fingerprint stays
	# stable across re-runs (clients accept it on first connect).
	if [ ! -f "$cert" ]; then
		sudo install -d -m 0755 /etc/gnome-remote-desktop
		sudo openssl req -x509 -nodes -newkey rsa:4096 -days 3650 \
			-subj "/CN=$(hostname)" -out "$cert" -keyout "$key"
		sudo chown gnome-remote-desktop:gnome-remote-desktop "$cert" "$key"
		sudo chmod 640 "$key"
	fi

	# Point the system (remote-login) RDP daemon at the cert and turn it on.
	sudo grdctl --system rdp set-tls-cert "$cert"
	sudo grdctl --system rdp set-tls-key "$key"
	sudo grdctl --system rdp enable

	# Gate credentials: prompted at install, never hardcoded.
	ensure_rdp_credentials

	# Open the RDP port only when a firewall is already active — never force ufw on.
	if command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
		sudo ufw allow 3389/tcp
	fi

	sudo systemctl enable gnome-remote-desktop.service
	sudo systemctl restart gnome-remote-desktop.service
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
		ffmpeg weasyprint poppler-utils qpdf webp libavif-bin

	# Docker (separate repo).
	install_docker

	# code-server (VS Code in the browser) — skip the download if already installed.
	if ! command -v code-server >/dev/null 2>&1; then
		curl -fsSL https://code-server.dev/install.sh | sh
	fi
	sudo systemctl enable --now "code-server@$USER"

	# Remote desktop (gnome-remote-desktop — see the function header for why not xrdp).
	setup_remote_desktop
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


# Append the dtach auto-router to ~/.profile once, so each login resumes sessions.
if ! grep -q "Aucune session dtach." "$HOME/.profile" 2>/dev/null; then
	cat >> "$HOME/.profile" << 'EOF'

DT=$(dt ls)
if [ "$DT" != "Aucune session dtach." ]; then
	dtach-router
fi
EOF
fi

echo "Done. Restart your shell or run: source ~/.bashrc"
echo "If you use zsh, switch to bash to enjoy these settings =)"
echo "Note: the deployed bashrc puts ~/.local/bin on PATH — re-login or run: source ~/.bashrc"

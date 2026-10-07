#!/usr/bin/env bash
# install.sh — deploy the vim + bash dotfiles. OS is auto-detected.
# Usage: ./install.sh
set -euo pipefail

# Resolve the repo root so the script works from any working directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Helpers are defined below; the identity itself is resolved right before the
# OS-specific steps, so every prompt comes before the long package installs.

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

# NVIDIA driver: only when an NVIDIA GPU is on the PCI bus (vendor id 10de), so the
# script stays hardware-agnostic elsewhere. ubuntu-drivers picks the driver the distro
# recommends for the card (595-open on the RTX 3060 Ti this was written on) instead of
# pinning a version that ages. Idempotent: a no-op when the recommended driver is in.
# The driver loads at the next reboot. Ubuntu-only (ubuntu-drivers-common).
install_nvidia_driver() {
	if ! command -v ubuntu-drivers >/dev/null 2>&1; then
		echo "ubuntu-drivers not found — skipping NVIDIA driver" >&2
		return 0
	fi
	if [ -z "$(lspci -d 10de: 2>/dev/null)" ]; then
		echo "No NVIDIA GPU detected — skipping NVIDIA driver"
		return 0
	fi
	echo "NVIDIA GPU detected — installing the recommended driver"
	sudo ubuntu-drivers install
	echo "NVIDIA driver loads at the next reboot."
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

# Disk-usage login warning: a profile.d snippet that warns (bold red) at login when
# / or /home cross the usage threshold. Deployed system-wide so every login shell
# sources it. /etc/profile.d is a Debian/Ubuntu convention and df --output=pcent is
# GNU-only, so this is Linux-only (called from the apt-get block). Idempotent: install
# overwrites in place and -D creates the dir if missing.
install_disk_warning() {
	echo "Installing disk-usage login warning to /etc/profile.d"
	sudo install -D -m 0644 "$SCRIPT_DIR/etc/profile.d/disk-usage-warning.sh" \
		/etc/profile.d/disk-usage-warning.sh
}

# The dtach session-resume menu now ships in ~/.bashrc (deployed above): every interactive
# shell sources it, including VS Code Remote-SSH terminals, which are non-login and therefore
# never read ~/.profile. This strips any dtach block a previous install left in ~/.profile —
# the marker-delimited managed one AND the legacy execute-based one (DT=$(dt ls) ... fi) — so
# the menu does not also fire from there (a plain SSH login sources ~/.bashrc via ~/.profile,
# which would otherwise prompt twice). No-op when absent. User scope, no sudo.
unwire_dtach_profile() {
	local profile="$HOME/.profile"
	[ -f "$profile" ] || return 0
	grep -qF 'dtach-router' "$profile" || return 0

	awk '
		$0 == "# >>> claude-dtach >>>" { drop = 1; next }
		$0 == "# <<< claude-dtach <<<" { drop = 0; next }
		drop { next }
		$0 == "DT=$(dt ls)", $0 == "fi" { next }
		{ print }
	' "$profile" > "$profile.tmp" && mv "$profile.tmp" "$profile"
}

# NAS helper, on request: deploys the on-demand CloudPex SMB mount command to
# /usr/local/bin (see cloudpex/README.md). Nothing is mounted and no credential is
# stored. Linux-only (cifs-utils); the helper's own installer is idempotent.
offer_cloudpex() {
	confirm "Install the cloudpex NAS mount helper (on-demand SMB mount)?" || return 0
	bash "$SCRIPT_DIR/cloudpex/install.sh"
}

# fail2ban: bans an IP on every port after repeated SSH failures. The sshd jail
# reads the journal (works with or without /var/log/auth.log) and bans all ports,
# so the port sshd listens on does not matter — the previous server's jail only
# banned port 22 while sshd listened on 337. Private LAN ranges are never banned.
# nftables is the ban backend. Idempotent: config overwritten, service restarted.
install_fail2ban() {
	echo "Installing fail2ban (sshd jail, all-ports ban)"
	sudo apt-get install -y fail2ban nftables
	sudo install -D -m 0644 "$SCRIPT_DIR/etc/fail2ban/jail.d/local.conf" \
		/etc/fail2ban/jail.d/local.conf
	sudo systemctl enable fail2ban
	sudo systemctl restart fail2ban
}

# Automatic security updates: the file dpkg-reconfigure would write, deployed
# directly so the install stays non-interactive. Idempotent.
install_unattended_upgrades() {
	echo "Enabling unattended security upgrades"
	sudo apt-get install -y unattended-upgrades
	sudo install -D -m 0644 "$SCRIPT_DIR/etc/apt/apt.conf.d/20auto-upgrades" \
		/etc/apt/apt.conf.d/20auto-upgrades
}

# sshd hardening drop-in (PermitRootLogin, MaxAuthTries, LoginGraceTime): only
# settings that cannot lock anyone out; authentication methods stay untouched.
# Validated with sshd -t before the reload. A rejected file is removed rather than
# left in place, so sshd keeps starting on the next boot; the install goes on and
# the warning tells you.
harden_sshd() {
	echo "Deploying sshd hardening drop-in"
	sudo install -D -m 0644 "$SCRIPT_DIR/etc/ssh/sshd_config.d/20-hardening.conf" \
		/etc/ssh/sshd_config.d/20-hardening.conf
	if ! sudo sshd -t; then
		sudo rm -f /etc/ssh/sshd_config.d/20-hardening.conf
		echo "sshd rejected 20-hardening.conf — removed, sshd config unchanged" >&2
		return 0
	fi
	sudo systemctl reload ssh
}

# Yes/no prompt for the optional system changes offered at the end of the install.
# Declines (returns 1) when no terminal is attached (curl | bash), so an offer is
# skipped with a hint instead of blocking; re-run ./install.sh from a terminal to
# get it offered again.
confirm() {
	local answer=""
	if [ ! -t 0 ]; then
		echo "Skipped (no terminal attached): $1" >&2
		return 1
	fi
	read -rp "$1 [y/N] " answer || true
	case "$answer" in
		[yY]|[yY][eE][sS]) return 0 ;;
		*) return 1 ;;
	esac
}

# /tmp on disk instead of the tmpfs Ubuntu mounts by default (RAM-backed, capped at
# 50% of RAM). Agent runs fill it: that eats half the RAM and, once the cap is hit,
# every temp-file creation fails with ENOSPC — which is what breaks shells. Masking
# tmp.mount leaves /tmp on the root filesystem; the tmpfiles rule keeps the tmpfs
# semantics (wiped at boot, entries older than 10 days purged). Takes effect at the
# next reboot: a busy /tmp is never unmounted live. Idempotent.
offer_tmp_on_disk() {
	if [ "$(systemctl is-enabled tmp.mount 2>/dev/null)" = "masked" ]; then
		echo "/tmp already on disk (tmp.mount masked) — skipping"
		return 0
	fi
	if [ "$(findmnt -n -o FSTYPE -T /tmp)" != "tmpfs" ]; then
		echo "/tmp is not a tmpfs — nothing to do"
		return 0
	fi
	confirm "Move /tmp from RAM (tmpfs) to disk? Agents fill it and break shells" || return 0
	sudo systemctl mask tmp.mount
	sudo install -D -m 0644 "$SCRIPT_DIR/etc/tmpfiles.d/tmp.conf" /etc/tmpfiles.d/tmp.conf
	echo "/tmp moves to disk at the next reboot."
}

# Keep SSH reachable when RAM runs out — the two rules the previous server ran:
#  - ssh.service drop-in: OOMScoreAdjust=-1000 (the kernel OOM killer never picks
#    sshd) + MemoryMin=256M (reclaim protection for the daemon's cgroup);
#  - earlyoom: kills the single largest process (node preferred, sshd/systemd spared)
#    once free RAM and free swap both drop under 10%, before the box thrashes.
# MemoryMin covers sshd only: logind puts login sessions in user.slice, so nothing can
# reserve RAM for a future shell — earlyoom acting in time is the real protection.
# Idempotent: each piece is skipped when already in place. Restarting ssh keeps the
# current sessions alive (KillMode=process).
offer_ssh_memory_guard() {
	local dropin="/etc/systemd/system/ssh.service.d/override.conf"
	local ssh_done=0 oom_done=0
	cmp -s "$SCRIPT_DIR/etc/systemd/ssh.service.d/override.conf" "$dropin" && ssh_done=1
	if cmp -s "$SCRIPT_DIR/etc/default/earlyoom" /etc/default/earlyoom \
		&& [ "$(systemctl is-enabled earlyoom 2>/dev/null)" = "enabled" ]; then
		oom_done=1
	fi
	if [ "$ssh_done" = 1 ] && [ "$oom_done" = 1 ]; then
		echo "SSH memory guard already in place — skipping"
		return 0
	fi
	confirm "Protect SSH under memory pressure (sshd OOM-exempt + earlyoom)?" || return 0
	if [ "$ssh_done" = 0 ]; then
		sudo install -D -m 0644 "$SCRIPT_DIR/etc/systemd/ssh.service.d/override.conf" "$dropin"
		sudo systemctl daemon-reload
		sudo systemctl restart ssh
	fi
	if [ "$oom_done" = 0 ]; then
		sudo apt-get install -y earlyoom
		sudo install -m 0644 "$SCRIPT_DIR/etc/default/earlyoom" /etc/default/earlyoom
		sudo systemctl enable earlyoom
		sudo systemctl restart earlyoom
	fi
}

# Put brew on this script's PATH (Apple Silicon: /opt/homebrew, Intel: /usr/local).
# Returns 1 when Homebrew is not installed.
load_brew_env() {
	local brew_bin
	for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
		if [ -x "$brew_bin" ]; then
			eval "$("$brew_bin" shellenv)"
			return 0
		fi
	done
	return 1
}

# Homebrew is the macOS stand-in for apt-get. Installed with its official script
# (asks for the sudo password, pulls the Xcode Command Line Tools: clang, make, git).
# Idempotent: a no-op when brew is already there.
ensure_homebrew() {
	load_brew_env && return 0
	echo "Installing Homebrew"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	load_brew_env
}

# The apt-get package list, mapped to Homebrew formulae. Linux-only packages are
# left out and listed by print_macos_gaps. php ships gd, mbstring, xml, intl, curl
# and mysql built in; bash is the bash 5 the bashrc needs (macOS ships 3.2).
install_brew_packages() {
	brew update
	brew upgrade
	brew install \
		vim git git-lfs git-filter-repo gitleaks pkgconf shellcheck gh git-delta \
		curl gnupg lftp inetutils \
		unzip tree tmux fzf dtach \
		node python pipx php \
		mariadb imagemagick \
		ffmpeg weasyprint poppler qpdf webp libavif \
		bash
}

# Start a Homebrew service at login, like systemctl enable --now. Skipped when
# already started, so a re-run never restarts a running database or VM.
start_brew_service() {
	local status
	status="$(brew services list | awk -v name="$1" '$1 == name { print $2 }')"
	if [ "$status" = "started" ]; then
		echo "$1 service already started — skipping"
		return 0
	fi
	brew services start "$1"
}

# Docker on macOS: the docker CLI talks to a Linux VM run by colima (free, no GUI,
# no Docker Desktop licence). compose and buildx are CLI plugins that brew installs
# outside Docker's search path, hence cliPluginsExtraDirs. An existing
# ~/.docker/config.json is never rewritten: a hint is printed instead.
install_colima_docker() {
	local config="$HOME/.docker/config.json"
	local plugins
	plugins="$(brew --prefix)/lib/docker/cli-plugins"
	brew install colima docker docker-compose docker-buildx
	if [ ! -f "$config" ]; then
		mkdir -p "$HOME/.docker"
		printf '{\n  "cliPluginsExtraDirs": ["%s"]\n}\n' "$plugins" > "$config"
	elif ! grep -qF "$plugins" "$config"; then
		echo "Add \"cliPluginsExtraDirs\": [\"$plugins\"] to $config for 'docker compose'" >&2
	fi
	start_brew_service colima
}

# macOS login shell: zsh (oh-my-zsh + zshrc-osx, the macOS default) or bash
# (brew's bash 5 + bashrc-osx). MACOS_SHELL=bash|zsh answers in advance; with no
# terminal attached and no answer, zsh. Prints the choice on stdout (the question
# goes to stderr).
choose_macos_shell() {
	local answer="${MACOS_SHELL:-}"
	if [ -z "$answer" ] && [ -t 0 ]; then
		read -rp "Login shell on macOS: zsh (oh-my-zsh) or bash? [zsh] " answer || true
	fi
	case "$answer" in
		zsh|"") echo zsh ;;
		bash) echo bash ;;
		*) echo "Unknown shell '$answer' — using zsh" >&2; echo zsh ;;
	esac
}

# Make $1 the login shell. /etc/shells must list it before chsh accepts it.
# chsh asks for the account password; a failure only prints a hint. Idempotent.
set_login_shell() {
	local target="$1" current
	if ! grep -qxF "$target" /etc/shells; then
		echo "$target" | sudo tee -a /etc/shells >/dev/null
	fi
	# id -un, not $USER: the deployed rc sets USER to the git/vim identity.
	current="$(dscl . -read "/Users/$(id -un)" UserShell | awk '{ print $2 }')"
	if [ "$current" = "$target" ]; then
		echo "Login shell already $target — skipping"
		return 0
	fi
	chsh -s "$target" || echo "chsh failed — run: chsh -s $target" >&2
}

# oh-my-zsh with its official script, unattended: no chsh (set_login_shell does
# it), no zsh launched mid-install, ~/.zshrc left alone (deploy_zsh_config owns
# it). Idempotent: skipped when ~/.oh-my-zsh exists.
install_oh_my_zsh() {
	if [ -d "$HOME/.oh-my-zsh" ]; then
		echo "oh-my-zsh already installed — skipping"
		return 0
	fi
	echo "Installing oh-my-zsh"
	KEEP_ZSHRC=yes sh -c \
		"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
		"" --unattended
}

# Deploy zshrc-osx to ~/.zshrc and the bchanot prompt theme into oh-my-zsh's
# custom themes. A ~/.zshrc that differs from the repo's is kept as
# ~/.zshrc.backup-<date>, not in ~/Oldconfig: that dir is wiped on every run, so
# a second run would destroy the original (and its nvm/bun lines).
deploy_zsh_config() {
	local name="$1" email="$2" rendered backup
	local themes="$HOME/.oh-my-zsh/custom/themes"
	backup="$HOME/.zshrc.backup-$(date +%Y%m%d-%H%M%S)"
	rendered="$(render_identity_template "$SCRIPT_DIR/zsh/zshrc-osx" "$name" "$email")"
	if [ -e "$HOME/.zshrc" ] && ! printf '%s\n' "$rendered" | cmp -s - "$HOME/.zshrc"; then
		echo "Saving the current ~/.zshrc to $backup"
		mv "$HOME/.zshrc" "$backup"
	fi
	echo "Deploying zsh/zshrc-osx + bchanot theme ($name <$email>)"
	printf '%s\n' "$rendered" > "$HOME/.zshrc"
	mkdir -p "$themes"
	cp "$SCRIPT_DIR/zsh/bchanot.zsh-theme" "$themes/"
}

# The chosen macOS shell ($1): zsh gets oh-my-zsh + its config rendered with the
# identity ($2 name, $3 email); bash needs brew's bash 5 (macOS ships 3.2, too
# old for the bashrc). Either way it becomes the login shell, so new terminals
# load the matching config.
setup_macos_shell() {
	if [ "$1" = zsh ]; then
		install_oh_my_zsh
		deploy_zsh_config "$2" "$3"
		set_login_shell /bin/zsh
	else
		set_login_shell "$(brew --prefix)/bin/bash"
	fi
}

# tmux, both OSes: tmux.conf goes to ~/.config/tmux/tmux.conf (read there since
# tmux 3.1: Ubuntu 22.04+, brew) with tpm, which the config runs, in
# ~/.config/tmux/plugins/tpm. tmux reads a ~/.tmux.conf first, so one found is
# moved aside; a differing config is kept as tmux.conf.backup-<date>, outside
# ~/Oldconfig which every run wipes. Idempotent.
deploy_tmux_config() {
	local dir="$HOME/.config/tmux" stamp
	stamp="$(date +%Y%m%d-%H%M%S)"
	mkdir -p "$dir"
	if [ -e "$HOME/.tmux.conf" ]; then
		echo "Moving ~/.tmux.conf to ~/.tmux.conf.backup-$stamp (it would shadow $dir/tmux.conf)"
		mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.backup-$stamp"
	fi
	if [ -e "$dir/tmux.conf" ] && ! cmp -s "$dir/tmux.conf" "$SCRIPT_DIR/tmux.conf"; then
		echo "Saving the current tmux.conf to $dir/tmux.conf.backup-$stamp"
		mv "$dir/tmux.conf" "$dir/tmux.conf.backup-$stamp"
	fi
	echo "Deploying tmux.conf to $dir"
	cp "$SCRIPT_DIR/tmux.conf" "$dir/tmux.conf"
	install_tmux_plugins "$dir/plugins/tpm"
}

# tpm plus the plugins tmux.conf lists, fetched now so the first tmux start is
# complete. tpm's script starts a tmux server to read @tpm_plugins, and the config
# expects XDG_CACHE_HOME (exported by the rc files, not loaded by this script).
# Failures only warn: prefix+I fetches the plugins from inside tmux.
install_tmux_plugins() {
	local tpm="$1"
	if [ ! -d "$tpm" ]; then
		echo "Cloning tpm"
		git clone --quiet https://github.com/tmux-plugins/tpm "$tpm"
	fi
	echo "Installing tmux plugins"
	XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}" "$tpm/bin/install_plugins" \
		|| echo "tmux plugins not installed — press prefix+I inside tmux" >&2
	install_libtmux
}

# tmux-window-name (a listed plugin) is a python script importing libtmux. Brew's
# python and Ubuntu 23.04+ refuse pip installs outside a venv (PEP 668), so the
# user-site install is retried with that guard lifted. Non-fatal: without it,
# windows keep tmux's own automatic-rename.
install_libtmux() {
	python3 -c 'import libtmux' 2>/dev/null && return 0
	echo "Installing libtmux (tmux-window-name plugin)"
	python3 -m pip install --quiet --user libtmux 2>/dev/null \
		|| python3 -m pip install --quiet --user --break-system-packages libtmux \
		|| echo "libtmux not installed — tmux-window-name stays inactive" >&2
}

# macOS terminals open LOGIN shells, which read ~/.bash_profile and never ~/.bashrc.
# Appends one line sourcing ~/.bashrc. Idempotent: skipped when already present.
wire_bash_profile() {
	local profile="$HOME/.bash_profile"
	# shellcheck disable=SC2016  # $HOME must expand when the profile runs, not now.
	local line='[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"'
	grep -qxF "$line" "$profile" 2>/dev/null && return 0
	echo "Wiring ~/.bash_profile to source ~/.bashrc"
	printf '\n# Load the interactive bash config (deployed by install.sh).\n%s\n' \
		"$line" >> "$profile"
}

# Value of `export NAME=value` ($1) in the rc file $2, quotes stripped. The last
# match wins, as when the shell sources it. Empty when absent.
rc_export_value() {
	sed -n "s/^export $1=//p" "$2" | tail -n 1 | tr -d "\"'"
}

# Print the template $1 with @USER@ and @EMAIL@ replaced by $2 and $3. Bash
# substitution, so the values need no sed escaping.
render_identity_template() {
	local file="$1" name="$2" email="$3" line
	while IFS= read -r line || [ -n "$line" ]; do
		line="${line//@USER@/$name}"
		line="${line//@EMAIL@/$email}"
		printf '%s\n' "$line"
	done < "$file"
}

# One identity value (USER or EMAIL, $1) for git commits, vim headers and the rc
# exports. Never stored in the repo. An export already in ~/.bashrc or ~/.zshrc
# wins silently (a re-run never asks twice), else IDENTITY_<VAR> from the
# environment, else a prompt ($2 label, $3 default) when a terminal is attached,
# else the default. Prints the value.
resolve_identity() {
	local var="$1" label="$2" default="$3" value="" rc envvar="IDENTITY_$1"
	for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
		[ -f "$rc" ] && value="$(rc_export_value "$var" "$rc")"
		if [ -n "$value" ] && [ "$value" != "@$var@" ]; then
			printf '%s\n' "$value"
			return 0
		fi
	done
	value="${!envvar:-}"
	if [ -z "$value" ] && [ -t 0 ]; then
		read -rp "$label [$default]: " value || true
	fi
	printf '%s\n' "${value:-$default}"
}

# Install the user-scope ~/.gitconfig (a repo's own .git/config still wins).
# The identity is read from the USER/EMAIL exports of the deployed rc ($1), so
# git and the shell agree. A ~/.gitconfig that differs is kept as
# ~/.gitconfig.backup-<date>, outside ~/Oldconfig which every run wipes.
# Idempotent: an identical ~/.gitconfig is left alone.
deploy_gitconfig() {
	local rc="$1" name email rendered backup
	name="$(rc_export_value USER "$rc")"
	email="$(rc_export_value EMAIL "$rc")"
	if [ -z "$name" ] || [ -z "$email" ]; then
		echo "USER/EMAIL not exported by $rc — skipping ~/.gitconfig" >&2
		return 0
	fi
	rendered="$(render_identity_template "$SCRIPT_DIR/gitconfig" "$name" "$email")"
	if printf '%s\n' "$rendered" | cmp -s - "$HOME/.gitconfig"; then
		echo "$HOME/.gitconfig already up to date — skipping"
		return 0
	fi
	if [ -e "$HOME/.gitconfig" ]; then
		backup="$HOME/.gitconfig.backup-$(date +%Y%m%d-%H%M%S)"
		echo "Saving the current ~/.gitconfig to $backup"
		mv "$HOME/.gitconfig" "$backup"
	fi
	echo "Deploying gitconfig to ~/.gitconfig ($name <$email>)"
	printf '%s\n' "$rendered" > "$HOME/.gitconfig"
}

# What the Linux install sets up that this macOS run did not, and why.
print_macos_gaps() {
	cat <<'EOF'

Not installed on macOS (compared with the Linux install):
  - gcc, make          Apple clang + make come with the Xcode Command Line Tools
                       (`gcc` runs clang). Real GCC: brew install gcc (gcc-15).
  - valgrind           not supported on macOS arm64. Use `leaks` or -fsanitize=address.
  - dkms               Linux kernel modules, no macOS equivalent.
  - net-tools          ifconfig / netstat / route are built into macOS.
  - openssh-server     built in, off by default: System Settings > General >
                       Sharing > Remote Login.
  - cifs-utils         SMB mounts are built in: mount_smbfs, or Finder Cmd-K.
  - ca-certificates, apt-transport-https   apt plumbing, not needed.
  - php-imagick        not bundled with brew php: pecl install imagick.
  - ubuntu-desktop-minimal + RDP (gnome-remote-desktop)   use Screen Sharing:
                       System Settings > General > Sharing > Screen Sharing.
  - NVIDIA driver      no NVIDIA GPU support on macOS.
  - disk-usage login warning (/etc/profile.d)   Linux-only (GNU df).
  - cloudpex NAS mount helper   Linux-only (cifs-utils).
  - fail2ban, unattended-upgrades, sshd hardening drop-in   Linux security baseline.
                       macOS: enable automatic updates in System Settings >
                       General > Software Update.
  - /tmp on disk + SSH memory guard offers   systemd-only.
Replaced: Docker engine -> colima VM + docker CLI; code-server and mariadb run
as brew services instead of systemd units.
EOF
}

# Identity for git, vim and the rc exports: reused from an existing rc, else asked.
identity_name="$(resolve_identity USER "Name for git commits and vim headers" "$(id -un)")"
identity_email="$(resolve_identity EMAIL "Email for git commits and vim headers" "")"
echo "Identity: $identity_name <${identity_email:-no email}>"

# System packages: apt-get on Debian/Ubuntu, Homebrew on macOS.
if command -v apt-get >/dev/null 2>&1; then
	sudo apt-get update
	sudo apt-get upgrade -y

	# Build + version control + C dev tooling (gitleaks backs the pre-commit hook,
	# git-delta provides `delta`, the pager set in gitconfig).
	# Web stack: MariaDB + PHP modules for local WordPress/LAMP work; the php-* metapackages
	# follow the distro's PHP version instead of pinning php8.x-*.
	sudo apt-get install -y \
		vim git git-lfs git-filter-repo gitleaks gcc make pkg-config dkms valgrind shellcheck git-delta \
		curl gnupg ca-certificates apt-transport-https \
		unzip tree tmux fzf dtach net-tools \
		openssh-server cifs-utils lftp ftp \
		nodejs python3-pip pipx php-cli \
		ffmpeg weasyprint poppler-utils qpdf webp libavif-bin gh \
		mariadb-server imagemagick \
		php-mysql php-gd php-imagick php-mbstring php-xml php-intl php-curl

	# Docker (separate repo).
	install_docker

	# code-server (VS Code in the browser) — skip the download if already installed.
	if ! command -v code-server >/dev/null 2>&1; then
		curl -fsSL https://code-server.dev/install.sh | sh
	fi
	# id -un, not $USER: the deployed bashrc sets USER to the git/vim identity.
	sudo systemctl enable --now "code-server@$(id -un)"

	# GNOME desktop (GDM + Shell): the RDP remote login below needs a GNOME session
	# to hand out; a bare server install has none. Ubuntu-only metapackage.
	sudo apt-get install -y ubuntu-desktop-minimal

	# Remote desktop (gnome-remote-desktop — see the function header for why not xrdp).
	setup_remote_desktop

	# NVIDIA driver, only when an NVIDIA GPU is present.
	install_nvidia_driver

	# Low-disk login warning (system-wide profile.d snippet).
	install_disk_warning

	# Security baseline: brute-force bans, automatic security updates, sshd limits.
	install_fail2ban
	install_unattended_upgrades
	harden_sshd
elif [ "$(uname -s)" = "Darwin" ]; then
	# Asked first, so the long brew steps below can run unattended.
	macos_shell="$(choose_macos_shell)"
	echo "macOS login shell: $macos_shell"

	ensure_homebrew
	install_brew_packages

	# Docker (colima VM), then code-server and MariaDB as login services.
	install_colima_docker
	brew install code-server
	start_brew_service code-server
	start_brew_service mariadb
else
	echo "Neither apt-get nor macOS — skipping system packages (install vim/git manually)."
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
cp -Rpv "$SCRIPT_DIR"/vim/* "$HOME/.vim/"
ln -sf "$HOME/.vim/vimrc" "$HOME/.vimrc"

# Deploy the bashrc matching the detected OS.
# macOS uses bashrc-osx (falling back to bashrc-linux if absent); everything else uses bashrc-linux.
if [ "$(uname -s)" = "Darwin" ] && [ -f "$SCRIPT_DIR/bash/bashrc-osx" ]; then
	bashrc="bash/bashrc-osx"
else
	bashrc="bash/bashrc-linux"
fi
echo "Deploying $bashrc ($identity_name <$identity_email>)"
render_identity_template "$SCRIPT_DIR/$bashrc" "$identity_name" "$identity_email" > "$HOME/.bashrc"

# User-scope git config, identity taken from the bashrc just deployed.
deploy_gitconfig "$SCRIPT_DIR/$bashrc"

# tmux config + plugins (tmux comes from the apt or brew list above).
if command -v tmux >/dev/null 2>&1; then
	deploy_tmux_config
fi

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


# Remove any stale dtach wiring from ~/.profile (the menu now ships in ~/.bashrc; see above).
unwire_dtach_profile

# Optional pieces, offered last so the base install is complete even when
# declined. Linux only. Each prompts [y/N] on a terminal, is skipped otherwise.
if command -v apt-get >/dev/null 2>&1; then
	offer_tmp_on_disk
	offer_ssh_memory_guard
	offer_cloudpex
fi

# macOS: login shells skip ~/.bashrc unless ~/.bash_profile sources it (kept even
# with zsh, so `bash` stays usable); set up the chosen shell, then report what the
# Linux install has that this one does not.
if [ "$(uname -s)" = "Darwin" ]; then
	wire_bash_profile
	setup_macos_shell "${macos_shell:-bash}" "$identity_name" "$identity_email"
	print_macos_gaps
fi

if [ "${macos_shell:-bash}" = zsh ]; then
	echo "Done. Open a new terminal or run: exec zsh"
	echo "Machine-specific zsh lines (nvm, bun...) go in ~/.zshrc.local"
else
	echo "Done. Restart your shell or run: source ~/.bashrc"
	echo "If you use zsh, switch to bash to enjoy these settings =)"
	echo "Note: the deployed bashrc puts ~/.local/bin on PATH — re-login or run: source ~/.bashrc"
fi

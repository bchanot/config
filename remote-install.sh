#!/usr/bin/env bash
# remote-install.sh — one-liner bootstrap: clone this repo, then run install.sh.
# Usage:
#   curl -fsSL https://git.bchanot.fr/bchanot/config/raw/branch/master/remote-install.sh | bash
# Override defaults with env vars:
#   REPO_URL=...  CLONE_DIR=...  BRANCH=...  curl ... | bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://git.bchanot.fr/bchanot/config.git}"
CLONE_DIR="${CLONE_DIR:-$HOME/config}"
BRANCH="${BRANCH:-master}"

# git is required to fetch the repo. Install it on Debian/Ubuntu, else bail with a hint.
if ! command -v git >/dev/null 2>&1; then
	if command -v apt-get >/dev/null 2>&1; then
		echo "git not found — installing via apt-get"
		sudo apt-get update
		sudo apt-get install -y git
	else
		echo "git not found and no apt-get available. Install git first, then re-run." >&2
		exit 1
	fi
fi

# Clone fresh, or update an existing checkout (idempotent re-runs).
if [ -d "$CLONE_DIR/.git" ]; then
	echo "Updating existing checkout at $CLONE_DIR"
	git -C "$CLONE_DIR" fetch --quiet origin "$BRANCH"
	git -C "$CLONE_DIR" checkout --quiet "$BRANCH"
	git -C "$CLONE_DIR" pull --quiet --ff-only origin "$BRANCH"
elif [ -e "$CLONE_DIR" ]; then
	echo "$CLONE_DIR exists but is not a git repo. Move it aside or set CLONE_DIR=..." >&2
	exit 1
else
	echo "Cloning $REPO_URL into $CLONE_DIR"
	git clone --quiet --branch "$BRANCH" "$REPO_URL" "$CLONE_DIR"
fi

# Hand off to the OS-detecting installer.
echo "Running install.sh"
bash "$CLONE_DIR/install.sh"

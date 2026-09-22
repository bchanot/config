#!/usr/bin/env bash
# cloudpex/install.sh — installe la commande `cloudpex` (montage à la demande du
# partage SMB CloudPex du NAS, voir README.md) telle qu'elle est déployée ici :
#   /usr/local/bin/cloudpex   root:root 0755
#   /mnt/cloudpex             point de montage (vide tant que rien n'est monté)
#   cifs-utils                installé si mount.cifs manque (apt-get)
# Réexécutable : réinstalle en place. Ne monte rien, ne stocke aucun identifiant.
# Usage : ./cloudpex/install.sh   (appelé aussi par ../install.sh sur Linux)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET=/usr/local/bin/cloudpex
MNT=/mnt/cloudpex

if ! command -v mount.cifs >/dev/null 2>&1; then
	if command -v apt-get >/dev/null 2>&1; then
		sudo apt-get install -y cifs-utils
	else
		echo "mount.cifs absent et apt-get introuvable : installe cifs-utils à la main" >&2
		exit 1
	fi
fi

sudo install -m 0755 -o root -g root "$SCRIPT_DIR/cloudpex" "$TARGET"
sudo install -d -m 0755 "$MNT"
echo "cloudpex installé : $TARGET (monter : cloudpex · état : cloudpex -s · démonter : cloudpex -u)"

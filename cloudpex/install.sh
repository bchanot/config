#!/usr/bin/env bash
# cloudpex/install.sh — installe la commande `cloudpex` (montage à la demande d'un
# partage SMB, voir README.md) telle qu'elle est déployée ici :
#   /usr/local/bin/cloudpex   le script, root:root 0755
#   /etc/cloudpex.conf        hôte, partage, utilisateur SMB, point de montage,
#                             version SMB : demandés ici, root:root 0600
#   cifs-utils                installé si mount.cifs manque (apt-get)
# Réexécutable : réinstalle le script en place et propose de garder la config
# existante. Sans terminal (curl | bash), la config n'est ni créée ni modifiée.
# Ne monte rien, ne stocke aucun mot de passe.
# Usage : ./cloudpex/install.sh   (appelé aussi par ../install.sh sur Linux)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET=/usr/local/bin/cloudpex
CONF=/etc/cloudpex.conf

die() { echo "Erreur : $*" >&2; exit 1; }

# Saisie validée : ask VAR "libellé" "défaut" "regex autorisée". Redemande tant
# que la valeur ne correspond pas ; la valeur vide prend le défaut.
ask() {
	local value
	while :; do
		read -rp "$2${3:+ [$3]} : " value || die "saisie interrompue"
		value="${value:-$3}"
		[[ $value =~ ^$4$ ]] && break
		echo "  valeur invalide, format attendu : $4" >&2
	done
	printf -v "$1" '%s' "$value"
}

# Demande les cinq valeurs propres au site et les écrit dans $CONF (root, 0600).
# Les formats refusent ce qui casserait la ligne d'options de mount.cifs
# (virgule, espace, guillemet) ; seul le nom de partage admet des espaces.
write_conf() {
	local host share user mnt vers tmp
	ask host  "Hôte du NAS (IP ou nom)" ""              '[A-Za-z0-9.-]+'
	ask share "Nom du partage SMB"      ""              '[A-Za-z0-9._ -]+'
	ask user  "Utilisateur SMB"         ""              '[A-Za-z0-9._-]+'
	ask mnt   "Point de montage"        "/mnt/cloudpex" '/[A-Za-z0-9._/-]+'
	ask vers  "Version SMB"             "3.0"           '[0-9]+(\.[0-9]+)*'
	tmp="$(mktemp)"
	printf 'HOST=%s\nSHARE=%s\nSMB_USER=%s\nMNT=%s\nSMB_VERS=%s\n' \
		"$host" "$share" "$user" "$mnt" "$vers" > "$tmp"
	sudo install -m 0600 -o root -g root "$tmp" "$CONF"
	rm -f "$tmp"
}

# Config : créée au clavier, ou gardée si elle existe déjà (répondre n pour la
# refaire). Sans terminal, rien n'est demandé.
configure() {
	local keep=""
	if [ ! -t 0 ]; then
		[ -f "$CONF" ] || echo "Pas de terminal : $CONF non créé, relance ./cloudpex/install.sh depuis un terminal" >&2
		return 0
	fi
	if [ -f "$CONF" ]; then
		echo "Configuration existante ($CONF) :"
		sudo sed 's/^/  /' "$CONF"
		read -rp "La garder ? [Y/n] " keep || true
		case "$keep" in
			[nN]*) write_conf ;;
		esac
	else
		write_conf
	fi
}

# Le point de montage déclaré dans la config, créé vide s'il manque.
ensure_mountpoint() {
	local mnt
	[ -f "$CONF" ] || return 0
	mnt="$(sudo sed -n 's/^MNT=//p' "$CONF" | head -n 1)"
	[ -n "$mnt" ] && sudo install -d -m 0755 "$mnt"
}

if ! command -v mount.cifs >/dev/null 2>&1; then
	command -v apt-get >/dev/null 2>&1 || die "mount.cifs absent et apt-get introuvable : installe cifs-utils à la main"
	sudo apt-get install -y cifs-utils
fi

sudo install -m 0755 -o root -g root "$SCRIPT_DIR/cloudpex" "$TARGET"
configure
ensure_mountpoint
echo "cloudpex installé : $TARGET (monter : cloudpex · état : cloudpex -s · démonter : cloudpex -u)"

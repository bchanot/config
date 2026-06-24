#!/bin/sh
# disk-usage-warning.sh — login-time low-disk warning.
# Deployed to /etc/profile.d/ by install.sh, so every login shell sources it.
# Warns in bold red when / or /home crosses THRESHOLD% usage.
THRESHOLD=85

check_disk() {
    mount_point="$1"
    usage=$(df "$mount_point" --output=pcent 2>/dev/null | tail -1 | tr -dc '0-9')
    [ -z "$usage" ] && return
    if [ "$usage" -ge "$THRESHOLD" ]; then
        printf '\033[1;31m'   # rouge gras
        printf '⚠  WARNING: %s à %s%% (seuil %s%%)\n' "$mount_point" "$usage" "$THRESHOLD"
        printf '\033[0m'
    fi
}

check_disk /home
check_disk /

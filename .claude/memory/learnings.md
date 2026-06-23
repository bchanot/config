# Learnings

Reusable patterns. Caveman + English.

## LRN-001 — Dotfiles installer idempotency pattern
2026-05-27. Re-runnable installer: `rm -rf` target before each `git clone`, `mkdir -p` dirs,
back up existing config to fixed `~/Oldconfig` (overwrite prev backup). Avoids "clone fails,
dir exists" on second run. Apply to any provisioning script.

## LRN-002 — Redundant vim plugin fetch
2026-05-27. molokai colorscheme committed in `vim/colors/` AND cloned to /tmp then copied.
`cp -rupv vim/* ~/.vim/` already deploys it. Dropped the clone. Lesson: check what tracked
files already cover before adding external fetch.

## LRN-003 — GNOME + xrdp working recipe (Ubuntu)
2026-06-23. `apt install xrdp` alone = black screen + auth popups. Need: `adduser xrdp ssl-cert`
(xrdp reads TLS key, else black screen on login); polkit rule allowing `org.freedesktop.color-manager.*`
(else recurring "Authentication required to create a color managed device" popups). Polkit format
version-gated: v>=0.106 → `/etc/polkit-1/rules.d/*.rules` (JS); older → `.pkla`. Verified live polkit
127 → `.rules` only (`.pkla` backend dropped). Open RDP 3389 only if firewall active. Restart xrdp
after group add so daemon reloads ssl-cert membership.

## LRN-004 — gnome-remote-desktop --system: remote desktop on Wayland-only GNOME
2026-06-23. xrdp does NOT work on Wayland-only GNOME (Shell asserts XDG_SESSION_TYPE=wayland, Xorg
backend dies instantly on login) → LRN-003 xrdp recipe N/A on such hosts. Use g-r-d system "Remote
Login": self-signed TLS cert via `grdctl --system rdp set-tls-cert/set-tls-key`, `rdp enable`,
enable+start `gnome-remote-desktop.service`. Auth = 2 layers: shared gate creds via `set-credentials`
(unlock GDM) THEN per-user PAM login. Gate creds REQUIRED — empty → mstsc 0x904/0x7 (BLK-004).
Listening socket + TLS + enable NOT enough alone. TPM warn `Init TPM credentials failed ... using
GKeyFile as fallback` = harmless on TPM-less host (creds → keyfile). Connect: client → ip:3389,
accept self-signed cert, gate creds, then GDM user. Supersedes LRN-003 for Wayland GNOME.

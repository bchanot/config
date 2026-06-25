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

## LRN-005 — df --output=pcent is GNU-only → keep /etc/profile.d disk scripts Linux-gated
2026-06-24. `df --output=pcent` (and `/etc/profile.d` itself) are GNU coreutils / Debian conventions,
absent on macOS BSD df. Any install step deploying such a snippet system-wide must sit inside the
`command -v apt-get` (Linux) block, never the OS-agnostic path. Deploy idempotently with
`sudo install -D -m 0644 src /etc/profile.d/x.sh` (-D makes the dir, overwrite = re-runnable). Caveat:
`/etc/profile.d/*.sh` runs for LOGIN shells only — non-login terminals need `/etc/bash.bashrc` instead.

## LRN-006 — Login-resume scripts must be SOURCED, not executed
2026-06-24. `dtach-router` (any login script that hands control back via `return` + attaches to host TTY)
must be SOURCED, never run as a command. Executed: its guard `case $- in *i*) ;; *) return 0 2>/dev/null ;;`
can't `return` from a non-sourced script → error swallowed by `2>/dev/null` → falls THROUGH the guard →
runs fzf + `dt at … >/dev/tty` → `/dev/tty: No such device or address` in EVERY non-interactive login shell
(`bash -lc`, cron, scp, tool sandbox). Repro'd live (fired on each Bash init). Fix in `~/.profile`:
`case $- in *i*) [ -x router ] && . router ;; esac`. Also: don't re-guard by parsing decorative output
(`[ "$(dt ls)" != "Aucune session dtach." ]`) — fragile (couples to exact string) AND redundant
(`dtach-router` already returns on empty `dt --raw`). Let the script self-guard. Bonus gotcha: `~/.profile`
is NOT read by bash if `~/.bash_profile` or `~/.bash_login` exists.

## LRN-007 — Doc-drift by file mtime misses partial doc updates
2026-06-25. `git log -1 --format=%aI -- README.md` reports "fresh" → false negative for staleness.
README touched in 46512ee (`docs(readme): fix wkhtmltopdf→weasyprint`, PACKAGE LIST ONLY) AFTER feature
commit 0bd936b (`gnome-remote-desktop + code-server`), so the mtime-based "commits since doc edit" scan
returned EMPTY while code-server + RDP stayed undocumented. A partial doc commit resets the clock and
hides earlier feature drift. Fix: drift-detect against FEATURE commits (scan `git log` for feat/* touching
source since the doc's last SUBSTANTIVE edit, OR cross-ref each entry-point / install-step in code vs doc
text) — never trust doc timestamp alone. Surfaced by /doc clean this session.

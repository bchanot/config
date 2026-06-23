# Blockers

Friction + root cause + status. Caveman + English.

## BLK-001 — vimrc GenerateClassC bare `name` var — OPEN
2026-05-27. `vim/vimrc` func `GenerateClassC` uses `name` instead of `a:name` → vimscript E121
undefined variable on `:ClassC Foo`. `GenerateClassH` correct (uses `a:name`). Not fixed —
vim domain, out of onboard scope (user said fix install.sh only). Fix: prefix all with `a:`.
Status: open, logged in TODO P2.

## BLK-002 — hardcoded OpenRouter key in claude-provider — RESOLVED (key rotation pending user)
2026-05-27. `~/.local/bin/claude-provider` had live `sk-or-v1-...` key in heredoc. Adding to
repo (remote git.bchanot.fr) would leak it. Root cause: key inlined in `write_openrouter`.
Fix: repo copy `bin/claude-provider` reads `${OPENROUTER_API_KEY:?...}` from env; key never in
repo. Verified `git grep sk-or` clean. Status: resolved in repo. ACTION user: revoke old key at
openrouter.ai (compromised — was in plaintext + exposed in chat).

## BLK-003 — xrdp block: `systemctl enable xrdb` typo aborted installer — RESOLVED
2026-06-23. Uncommitted install.sh xrdp block had `sudo systemctl enable xrdb` (typo: `xrdb` = X
resource-DB tool, no such systemd service). Returns non-zero → under `set -euo pipefail` aborts
whole installer. Also `apt-get install xrdp` missing `-y` → hangs non-interactive run. Root cause:
one-letter typo `xrdp`→`xrdb` + missing -y. Fix: idempotent `install_xrdp()` (apt -y, adduser xrdp
ssl-cert, polkit .rules, conditional ufw 3389, enable+restart). shellcheck + bash -n CLEAN.
Status: resolved in repo. Not run live / RDP connection not tested.

## BLK-004 — RDP Win→Linux 0x904/0x7: empty gate creds on g-r-d --system — RESOLVED
2026-06-23. After xrdp dropped for gnome-remote-desktop (Wayland), mstsc fails `0x904 / 0x7`
despite: daemon LISTEN *:3389, ufw inactive, TLS cert readable, service active. Root cause:
`grdctl --system status` → `Username: (empty)` / `Password: (empty)`. System "Remote Login" =
2-layer auth: shared gate creds (`grdctl --system rdp set-credentials`) unlock GDM, then per-user
PAM login at GDM. Empty gate creds → RDP nego refused before GDM → 0x904. Fix: set-credentials,
connect (gate creds → GDM `bchanot`). Connection CONFIRMED live. Automated in install.sh via
ensure_rdp_credentials (prompt, TTY-guarded, idempotent). Supersedes BLK-003 (xrdp). Status: resolved.

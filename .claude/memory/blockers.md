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

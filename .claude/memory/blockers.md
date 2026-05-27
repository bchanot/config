# Blockers

Friction + root cause + status. Caveman + English.

## BLK-001 — vimrc GenerateClassC bare `name` var — OPEN
2026-05-27. `vim/vimrc` func `GenerateClassC` uses `name` instead of `a:name` → vimscript E121
undefined variable on `:ClassC Foo`. `GenerateClassH` correct (uses `a:name`). Not fixed —
vim domain, out of onboard scope (user said fix install.sh only). Fix: prefix all with `a:`.
Status: open, logged in TODO P2.

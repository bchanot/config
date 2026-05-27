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

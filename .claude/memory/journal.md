# Journal

3-5 lines/session. Caveman + English.

## 2026-05-27 — onboard (right-sized)
Onboarded dotfiles repo. Archetype dotfiles-meta HAUTE. 8 files, ~405 lines, graphify skipped.
Found + fixed install.sh: broken /tmp/config paths (server+osx silent fail), bashism under sh,
missing cp -r nerdtree, redundant molokai clone, unquoted vars, no set -eu. shellcheck CLEAN.
Created README, CLAUDE.md, .gitignore, .claude memory/tasks/audits. No secrets found.
Open: vimrc GenerateClassC bug (BLK-001), bashrc backtick style nits.
Then: install.sh arg dropped → uname OS-detect (Darwin→osx else linux). Deleted bashrc-server.
Added remote-install.sh curl|bash bootstrap (BDR-004). shellcheck CLEAN. Docs synced.
Committed in 4 atomic commits (chore claude / refactor install / feat remote-install / docs).
Slip: staged deletion swept into commit 1; fixed via soft-reset + restore --staged. Unpushed.

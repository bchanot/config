# PLAN — tmux-bell-highlight (hotfix)

## Root cause
tmux.conf:15 `set -g bell-action none`. bell-action only decides whether a bell is
forwarded to the client terminal → user hears no bell since tmux. The tab flag is
governed by monitor-bell (default on): a bell in a non-current window sets
WINLINK_BELL, drawn with window-status-bell-style (default `reverse`) until the
window is visited → several tabs highlighted at once.

## Fix (tmux.conf, line 15 area, 2 lines)
- `set -g bell-action none  # make it Shut up!` → `set -g bell-action any`
  (forward bells from every window of the attached session, tmux default;
  sessions with no attached client stay silent).
- add `setw -g window-status-bell-style default` (flag kept, no visual: only the
  current tab stands out). Status formats use #I #W, not #F, so no `!` either.

- one why-comment above the pair (bell sent to terminal; tab flag kept but
  unstyled; monitor-bell must stay on or no bell is sent). [challenge simplicity#1]

## After merge (not in repo diff) [challenge correctness#1, robustness#1]
Live server: main loop runs `tmux set -g bell-action any; tmux set -wg monitor-bell on;
tmux set -wg window-status-bell-style default`. Deployed copy ~/.config/tmux/tmux.conf
is a cp (install.sh:569): user redeploys (./install.sh or cp) on each host, then prefix R.
Rollback: revert, `setw -gu window-status-bell-style`, prefix R. [robustness#2]

## Not changed
monitor-bell stays on (default): alerts_check_bell() returns early when it is off,
so no bell would reach the terminal. monitor-activity already off.

# CONTRACT — tmux-bell-highlight
- date: 2026-11-13 | flow: hotfix | branch: bugfix/tmux-bell-highlight

## REQUEST (verbatim — IMMUTABLE)
il y a un petit probleme dans les onglet tmux, sur le highlight des onlget, il y a souvent plusieurs onglet qui sont highlight plutot que juste l'onglet courant
→ "j'ai plus de bells depuis que je suis passe a tmux"

## CLARIFICATIONS
Q: bell behaviour? / A: sound back, no tab highlight ("Son, sans highlight") [gated 2026-11-13]
Q: dirty .githooks/pre-commit? / A: leave it, targeted commit of tmux.conf only [gated 2026-11-13]
Note: bell-action `any` (tmux default, all windows ring = pre-tmux behaviour) instead of
`other` offered in the question: `other` would silence the current tab. Deviation reported to user.

## ACCEPTANCE CRITERIA
1. tmux.conf loads clean; bell-action any; window-status-bell-style default
   CHECK: bare scratch server (no tpm/continuum restore), only the bell lines applied:
     tmux -L bellchk -f /dev/null new-session -d -s t; grep -E '^set(w)? .*bell' tmux.conf | sed 's/ *#.*//' | while read -r l; do eval "tmux -L bellchk $l"; done; tmux -L bellchk show -gv bell-action; tmux -L bellchk show -gwv window-status-bell-style; tmux -L bellchk kill-server
   EXPECT: any / default
2. Only tmux.conf changed by this fix (.githooks/pre-commit pre-existing, untouched)

3. A why-comment above the pair says monitor-bell must stay on

## FILE SCOPE
tmux.conf

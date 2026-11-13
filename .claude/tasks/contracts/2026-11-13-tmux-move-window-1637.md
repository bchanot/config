# CONTRACT — tmux-move-window
- date: 2026-11-13 | flow: hotfix | branch: feature/tmux-move-window
- status: abandoned (smoke 2 failed: focus stays on slot; superseded)

## REQUEST (verbatim — IMMUTABLE)
comment deplacer un onglet de gauche a droite dnas la liste des onglet sur tmux ?
→ (after proposal of prefix < / > bindings) "oui ajoute le"

## CLARIFICATIONS
Q: keys? / A: prefix < and > (proposed, accepted) [gated 2026-11-13]
Q: focus? / A: focus follows moved window (no -d, no extra select-window) [gated 2026-11-13]

## ACCEPTANCE CRITERIA
1. tmux.conf loads clean and prefix table binds < / > to swap-window -t -1 / +1
   CHECK: tmux -L tmvchk -f tmux.conf new-session -d -s t && tmux -L tmvchk list-keys -T prefix | grep -E 'prefix +[<>] +swap-window -t [-+]1' | wc -l; tmux -L tmvchk kill-server
   EXPECT: 2
   EVIDENCE: pending
2. swap-window -t -1 on window 3 of 3 moves it to slot 2 and it stays current
   CHECK: headless scratch socket, window ids compared before/after
   EXPECT: moved id at index 2, active
   EVIDENCE: pending
3. shellcheck/bash -n unaffected (tmux.conf not linted); no other file changed

## FILE SCOPE
tmux.conf

# CONTRACT — tmux-move-window-v2
- date: 2026-11-13 | flow: hotfix | branch: feature/tmux-move-window
- status: active

## REQUEST (verbatim — IMMUTABLE)
comment deplacer un onglet de gauche a droite dnas la liste des onglet sur tmux ?
→ "oui ajoute le" → (after failed v1) "biensur reecris et applique"

## CLARIFICATIONS
Q: keys? / A: prefix < and > [gated 2026-11-13]
Q: focus? / A: follows moved window → swap-window then select-window same offset (swap alone keeps focus on slot, tested tmux 3.6) [gated 2026-11-13]

## ACCEPTANCE CRITERIA
1. prefix table binds < / > to swap-window ±1 + select-window ±1
   CHECK: tmux -L tmvchk -f tmux.conf new-session -d -s t && tmux -L tmvchk list-keys -T prefix | grep -cE 'prefix +[<>] +swap-window -t [-+]1 \; select-window -t [-+]1'; tmux -L tmvchk kill-server
   EXPECT: 2
   EVIDENCE: pending
2. Window 3 of 3, bound command for <: moved id at index 1 and active
3. Only tmux.conf changed

## FILE SCOPE
tmux.conf

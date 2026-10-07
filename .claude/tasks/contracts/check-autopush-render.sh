#!/usr/bin/env bash
# Oracle for the contract: exercises install.sh functions on scratch HOMEs under
# mktemp; never reads or writes the real ~/.gitconfig and never calls git config.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
SCRIPT_DIR="$PWD"

fail() { echo "FAIL: $*" >&2; exit 1; }
fresh_home() { HOME="$(mktemp -d)"; export HOME; }
guard_home() {
	case "$HOME" in /tmp/*|/private/*|/var/*) ;; *) fail "refusing HOME=$HOME" ;; esac
}
has() { grep -qF -- "$2" "$1" || fail "$1 lacks: $2"; }

funcs="$(mktemp)"
for fn in ask_autopush resolve_autopush render_identity_template \
	render_gitconfig deploy_gitconfig; do
	sed -n "/^$fn() {/,/^}/p" install.sh >> "$funcs"
done
source "$funcs"
shopt -u patsub_replacement 2>/dev/null || true
unset DOTFILES_GITFLOW_AUTOPUSH

# Case A: render
fresh_home; guard_home
[ "$(DOTFILES_GITFLOW_AUTOPUSH=false resolve_autopush </dev/null)" = false ] \
	|| fail "A: preset false"
deploy_gitconfig x x@y false >/dev/null
for l in 'autopush = false' 'name = x' 'email = x@y' 'hooksPath = ~/.claude/githooks'; do
	has "$HOME/.gitconfig" "$l"
done
! grep -qE '@(USER|EMAIL|AUTOPUSH)@' "$HOME/.gitconfig" || fail "A: placeholder left"

# Case I: idempotent re-run in A's HOME
out="$(deploy_gitconfig x x@y false)"
case "$out" in *"already up to date"*) ;; *) fail "I: not skipped: $out" ;; esac
ls "$HOME"/.gitconfig.backup-* >/dev/null 2>&1 && fail "I: backup created"

# Case A2: ampersand
fresh_home; guard_home
deploy_gitconfig 'a & b' x@y true >/dev/null
has "$HOME/.gitconfig" 'name = a & b'

# Case B: leaked placeholder
fresh_home; guard_home
set +e; deploy_gitconfig x x@y '@AUTOPUSH@' 2>"$HOME/err"; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "B: rc 0"
has "$HOME/err" '@AUTOPUSH@'
[ ! -e "$HOME/.gitconfig" ] || fail "B: file written"

# Case C: existing wins over preset
fresh_home; guard_home
printf '[gitflow]\n    autopush = true\n' > "$HOME/.gitconfig"
[ "$(DOTFILES_GITFLOW_AUTOPUSH=false resolve_autopush </dev/null)" = true ] || fail "C"

# Case D: defaults
fresh_home; guard_home
[ "$(resolve_autopush </dev/null)" = true ] || fail "D"

# Case E: strict preset
set +e; DOTFILES_GITFLOW_AUTOPUSH=yes resolve_autopush 2>"$HOME/err" </dev/null; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "E: rc 0"
has "$HOME/err" exactly

# Case F: prompt loop
[ "$(printf 'yes\ntrue\n' | ask_autopush 2>"$HOME/err")" = true ] || fail "F1"
has "$HOME/err" exactly
[ "$(printf '\n' | ask_autopush)" = true ] || fail "F2"

# Case G: empty email
fresh_home; guard_home
deploy_gitconfig x "" true 2>"$HOME/err"
[ ! -e "$HOME/.gitconfig" ] || fail "G: file written"
has "$HOME/err" "not written"

# Case H: call site
grep -q 'deploy_gitconfig "\$identity_name" "\$identity_email" "\$autopush"' install.sh \
	|| fail "H: call site"
! grep -q 'deploy_gitconfig "\$SCRIPT_DIR' install.sh || fail "H: template path"

# Case J: non-exact existing value
fresh_home; guard_home
printf '[gitflow]\n    autopush = off\n' > "$HOME/.gitconfig"
[ "$(resolve_autopush 2>"$HOME/err" </dev/null)" = true ] || fail "J: value"
has "$HOME/err" off

# Case K: refused value
fresh_home; guard_home
set +e; deploy_gitconfig x x@y yes 2>"$HOME/err"; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "K: rc 0"
has "$HOME/err" "not exactly"
[ ! -e "$HOME/.gitconfig" ] || fail "K: file written"

echo AUTOPUSH_RENDER_OK

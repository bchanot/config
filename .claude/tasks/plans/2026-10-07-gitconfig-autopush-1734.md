# PLAN — gitconfig-autopush (feat) — REVISED v4 (round 1 + user spec + confirmation pass, default true)
Contract: .claude/tasks/contracts/2026-10-07-gitconfig-autopush-1734.md
Branch: feature/gitconfig-autopush (off develop)

## Goal (user spec, verbatim constraints in the contract)
1. `gitconfig` template, section `[core]`: fixed line `hooksPath = ~/.claude/githooks`
   (git expands `~` itself for core.hooksPath; no absolute path, no expansion by the
   script; the installer neither creates nor checks that directory).
2. install.sh asks at install: automatic push by the gitflow hooks on this machine?
   `[true/false]` (default: true — user correction). Answer rendered into a new section
   `[gitflow]` / `autopush = @AUTOPUSH@`.
   - Only the exact strings `true` and `false` are accepted. Anything else re-asks;
     an empty answer gives `true`.
   - The render FAILS explicitly (grep after render) if `@AUTOPUSH@` is still in the
     final content. A non-boolean value blocks every push on the machine (fail-closed),
     so a leaked placeholder would be a silent outage.
   - Non-interactive install: env `DOTFILES_GITFLOW_AUTOPUSH=true|false`, default true.
3. Keep the existing backup (`~/.gitconfig.backup-<timestamp>`). Do not touch the other
   template sections.
4. Human-gated 2026-10-07 (kept from round 1): fix the identity call site so the deployed
   file carries the resolved name/email, not the literal `@USER@`/`@EMAIL@`.
5. The user sees the full diff BEFORE anything is committed (working tree only until then).

## Context (verified)
- `gitconfig` is a template; `render_identity_template` (install.sh:497) replaces
  @USER@/@EMAIL@ by bash substitution over every line (comments included).
- `deploy_gitconfig` (install.sh:532) takes an rc PATH and reads USER/EMAIL from it.
  BUG: the call site install.sh:688 passes `"$SCRIPT_DIR/$bashrc"` = the repo TEMPLATE
  whose exports are `export USER="@USER@"` (bash/bashrc-linux:33-34). The placeholders
  are non-empty, the guard passes, the deployed file reads `name = @USER@`.
- Identity resolved at install.sh:584-585 into `identity_name` / `identity_email`, before
  package installs (prompts first). EMAIL default "" when no tty and no env.
- Readers (~/.claude/lib/gitflow.sh gitflow_push_mode, post-commit/post-merge hooks):
  `git config --bool gitflow.autopush` → false = manual, true/unset = auto, other =
  invalid → nothing pushed (fail closed). Only exact `true`/`false` are ever written.
- `core.hooksPath` is a pathname-typed key: git tilde-expands `~/.claude/githooks`.
  Today `make link` writes it with `git config --global`; the redeploy dropped it. With
  the fixed template line the redeploy keeps it and the file matches the render again.
- This session's permission layer denies every `git config … gitflow.*` command, so the
  installer and the oracle must NOT read or write the key through git: an existing value
  is read from ~/.gitconfig with sed (same shape as rc_export_value). Trade-off: a value
  set in XDG/system/included config is not seen; ~/.gitconfig is the only file written.
- install.sh runs under macOS /bin/bash 3.2 before brew bash exists (LRN-014): plain
  string compares only, no `${var,,}`.
- The repo has no test suite and install.sh has no --dry-run: the oracle harness below is
  the test, run by the contract gate.

## Checklist
  [ ] gitconfig — header comment (lines 1-4) reworded WITHOUT literal placeholder tokens
      (today it renders as "bchanot and x@y are replaced at install time"): "Template for
      the user-scope ~/.gitconfig, rendered by install.sh. Git never expands $VARS, so the
      identity and the gitflow push mode are placeholders filled at install time with the
      installer's answers. A repo .git/config still overrides these values for that repo."
      In `[core]`, after `excludesfile`, add the fixed line:
          hooksPath = ~/.claude/githooks
      with a one-line comment above it: "# gitflow hooks (created by `make link` in
      claude-config); git expands ~ itself." After `[user]`, add:
          [gitflow]
              # Push mode of the gitflow hooks: false = manual, you run `git push`;
              # true = every commit and merge is pushed. Exact true/false only (fail-closed).
              autopush = @AUTOPUSH@
      4-space indent like the other keys. No other section touched.
  [ ] install.sh — two new functions right after `resolve_identity` (~line 525), tabs:
        # Ask the push question on the terminal until the answer is exactly true or false;
        # Enter (or EOF) = true. Prints the value.
        ask_autopush() {
        	local answer=""
        	while :; do
        		read -rp "Automatic push of commits by the gitflow hooks on this machine? [true/false] (default: true) " answer || true
        		case "${answer:-true}" in
        			true|false) printf '%s\n' "${answer:-true}"; return 0 ;;
        			*) echo "Answer exactly true or false." >&2 ;;
        		esac
        	done
        }

        # Push mode of the gitflow hooks (gitflow.autopush), exact true/false only: the
        # readers fail closed on anything else. Never asked twice: a true/false already in
        # ~/.gitconfig wins silently (read with sed, like rc_export_value, so a hand-set
        # value survives the redeploy; a non-exact spelling is named and re-asked), else
        # DOTFILES_GITFLOW_AUTOPUSH (anything but true/false aborts the install here,
        # before any file is touched, whatever ~/.gitconfig holds), else the prompt
        # on a terminal, else true (today's unset = auto). Prints the value.
        resolve_autopush() {
        	local value="" preset="${DOTFILES_GITFLOW_AUTOPUSH:-}"
        	case "$preset" in
        		true|false|"") ;;
        		*) echo "DOTFILES_GITFLOW_AUTOPUSH='$preset' — must be exactly true or false" >&2; return 1 ;;
        	esac
        	if [ -f "$HOME/.gitconfig" ]; then
        		value="$(sed -n 's/^[[:space:]]*autopush[[:space:]]*=[[:space:]]*//p' "$HOME/.gitconfig" | tail -n 1)"
        		case "$value" in
        			true|false) printf '%s\n' "$value"; return 0 ;;
        			"") ;;
        			*) echo "gitflow.autopush='$value' in ~/.gitconfig is not exactly true/false — asking again" >&2 ;;
        		esac
        	fi
        	if [ -n "$preset" ]; then printf '%s\n' "$preset"; return 0; fi
        	if [ -t 0 ]; then ask_autopush; else echo true; fi
        }
      Order: preset syntax is validated FIRST (a bad preset always aborts, even on a
      re-run), then an existing exact value wins, then a valid preset, prompt, default.
      Each ≤ 25 logic lines. `read … || true` on EOF → empty → true → loop ends.
  [ ] install.sh — after `set -euo pipefail` (line 4) add, with a one-line comment
      ("bash ≥ 5.2 expands `&` in ${var//pat/rep} replacements: an `&` in a name would
      corrupt the rendered identity; no-op on bash 3.2"):
        shopt -u patsub_replacement 2>/dev/null || true
  [ ] install.sh — main sequence, right after identity_email (line 585):
        autopush="$(resolve_autopush)"
      (set -e: a `return 1` from an invalid preset aborts the install right here.)
  [ ] install.sh — `deploy_gitconfig` becomes `deploy_gitconfig <name> <email> <autopush>`
      (no rc path, no rc_export_value call):
        local name="$1" email="$2" autopush="$3" rendered backup
        if [ -z "$name" ] || [ -z "$email" ]; then
        	echo "Name or email empty — skipping ~/.gitconfig (push mode $autopush not written)" >&2
        	return 0
        fi
        rendered="$(render_identity_template "$SCRIPT_DIR/gitconfig" "$name" "$email")"
        case "$autopush" in true|false) ;; *)
        	echo "gitconfig render refused: push mode '$autopush' is not exactly true/false — nothing written" >&2
        	return 1 ;;
        esac
        rendered="${rendered//@AUTOPUSH@/$autopush}"
        case "$rendered" in *@AUTOPUSH@*)
        	echo "gitconfig render failed: @AUTOPUSH@ left in the output — nothing written" >&2
        	return 1 ;;
        esac
        (no pipe: `printf | grep -q` under pipefail can read SIGPIPE as "no leak")
        … cmp/skip, backup, write unchanged …
        echo "Deploying gitconfig to ~/.gitconfig ($name <$email>, autopush=$autopush)"
      Header comment rewritten: $1 $2 = the identity rendered into the rc, $3 = push mode;
      one line on the two fail-closed checks. If > 25 logic lines, extract
      `render_gitconfig <name> <email> <autopush>` (render + substitution + grep).
  [ ] install.sh:688 call site → `deploy_gitconfig "$identity_name" "$identity_email" "$autopush"`
      comment: "User-scope git config, same identity as the rc just rendered."
  [ ] README.md:31 gitconfig row — "`@USER@`, `@EMAIL@` and `@AUTOPUSH@` (gitflow push
      mode) are filled at install with the installer's answers; `core.hooksPath` points at
      the gitflow hooks `make link` creates."
  [ ] README.md:50 — "(identity, push mode, macOS shell, offers)".
  [ ] README.md:70 step 6 — replace "with the same `USER` / `EMAIL`" by "with the same name
      and email", then add: the installer asks once whether the gitflow hooks push every
      commit and merge (`true`/`false` exactly, Enter = `true`); a `true`/`false` already
      in `~/.gitconfig` is reused without asking and survives the redeploy;
      `DOTFILES_GITFLOW_AUTOPUSH=true|false` presets it for a non-interactive install (no
      terminal and no preset → `true`; any other preset aborts the install); the render
      refuses to write a file where `@AUTOPUSH@` leaked, since a non-boolean value blocks
      every push. To switch later: `git config --global gitflow.autopush true|false`.
  [ ] CLAUDE.md:25 — `gitconfig  user-scope ~/.gitconfig template, @USER@/@EMAIL@/@AUTOPUSH@
      (gitflow push mode, exact true/false) filled at install; core.hooksPath fixed`
  [ ] .claude/tasks/contracts/check-autopush-render.sh — oracle harness (LRN-011 pattern):
      `set -euo pipefail`; `cd "$(git rev-parse --show-toplevel)"` (the only git call, no
      config access); `SCRIPT_DIR="$PWD"`. Extract ask_autopush, resolve_autopush,
      render_identity_template, deploy_gitconfig (and render_gitconfig if extracted) from
      install.sh via `sed -n '/^fn() {/,/^}/p'` into `$(mktemp)` and source it.
      `fresh_home() { HOME="$(mktemp -d)"; export HOME; }` before every case; guard
      `case "$HOME" in /tmp/*|/private/*|/var/*) ;; *) fail "refusing HOME=$HOME";; esac`
      before any deploy call. No rm of temp dirs (never rm -rf through a variable).
      `fail() { echo "FAIL: $*" >&2; exit 1; }`; every assertion goes through it.
      stderr captures go to `"$HOME/err"` (the scratch HOME), never a relative path in
      the repo. Header comment: "Oracle for the contract: exercises install.sh functions
      on scratch HOMEs under mktemp; never reads or writes the real ~/.gitconfig and never
      calls git config." If the permission layer refuses a step of this harness, the
      refusal is reported with its rule and the harness is handed to the user to run; it
      is never reworked to get around the rule.
      Case A (render): fresh_home; DOTFILES_GITFLOW_AUTOPUSH=false </dev/null →
        resolve_autopush = false; deploy_gitconfig x x@y false → file has
        `autopush = false`, `name = x`, `email = x@y`, `hooksPath = ~/.claude/githooks`,
        and `! grep -qE '@(USER|EMAIL|AUTOPUSH)@'`.
      Case A2 (ampersand): fresh_home; deploy_gitconfig 'a & b' x@y true → file has
        `name = a & b` (patsub_replacement off; bash 3.2 passes trivially).
      Case B (leaked placeholder = failure): fresh_home; `set +e; deploy_gitconfig x x@y
        '@AUTOPUSH@' 2>err; rc=$?; set -e` → rc != 0, err contains "@AUTOPUSH@", no
        ~/.gitconfig written. (Passing the placeholder as the value is the only way to
        make the substitution a no-op; it stands in for a broken template.)
      Case C (existing wins): fresh_home; printf '[gitflow]\n    autopush = true\n' >
        "$HOME/.gitconfig"; DOTFILES_GITFLOW_AUTOPUSH=false </dev/null → true.
      Case D (defaults): fresh_home; no file, env unset, </dev/null → true.
      Case E (strict preset): DOTFILES_GITFLOW_AUTOPUSH=yes </dev/null → `set +e;
        resolve_autopush 2>err; rc=$?; set -e` → rc != 0, err contains "exactly".
      Case F (prompt loop): `printf 'yes\ntrue\n' | ask_autopush 2>err` → true, err
        contains "exactly"; `printf '\n' | ask_autopush` → true.
      Case G (empty email): deploy_gitconfig x "" true 2>err → no file, err has "not written".
      Case H (call site): `grep -q 'deploy_gitconfig "\$identity_name" "\$identity_email" "\$autopush"' install.sh`
        and `! grep -q 'deploy_gitconfig "\$SCRIPT_DIR' install.sh`.
      Case I (idempotent): run right after Case A in Case A's HOME (no fresh_home between
        them): deploy_gitconfig x x@y false again → stdout contains "already up to date",
        no `.gitconfig.backup-*` created.
      Case J (non-exact existing): fresh_home; printf '[gitflow]\n    autopush = off\n' >
        "$HOME/.gitconfig"; env unset, </dev/null → prints true and stderr names "off".
      Case K (refused value): `set +e; deploy_gitconfig x x@y yes 2>"$HOME/err"; rc=$?; set -e`
        → rc != 0, err contains "not exactly", no file.
      Print AUTOPUSH_RENDER_OK only at the end.

## Edge cases
- Non-exact existing value: `off`/`no`/`0` are VALID false for the readers (`--bool`),
  `maybe` is invalid (nothing pushed). Neither is reused (strict grammar): the value is
  named on stderr, then preset/prompt/default decide. With no tty and no preset a
  hand-set `off` becomes `true`: accepted consequence of the strict grammar + default
  true, documented in the README sentence on switching the mode.
- Re-run: value found in ~/.gitconfig → no prompt → identical render → "already up to
  date — skipping" (now holds with hooksPath in the template).
- No tty (curl | bash without /dev/tty) and no preset → true: same as today's unset = auto.
- Invalid preset aborts before Oldconfig/rm or any write (resolution happens at the
  identity step).
- Empty email → file skipped, dropped push mode named in the warning.
- `.githooks/post-commit` / `.githooks/post-merge` are dirty from the session hook
  refresh: do not touch, do not stage.
- Known, not handled: a system-scope `/etc/gitconfig` value is shadowed by the written
  global one (blockers entry at CAPITALIZE).

## Tests
- `bash -n install.sh`, `shellcheck install.sh`.
- `bash .claude/tasks/contracts/check-autopush-render.sh` → AUTOPUSH_RENDER_OK.

## Disposition (memory read-before)
- honors BDR-001 (bash) — bash substitutions, `read -rp`.
- honors BDR-002 — template read via `$SCRIPT_DIR/gitconfig`.
- BDR-012 pattern (installer prompts, re-ask on bad input, keep-existing, no TTY →
  default) honored on the interactive path; DEVIATION flagged: an invalid
  DOTFILES_GITFLOW_AUTOPUSH preset aborts the install (user's fail-closed requirement),
  before any file is touched.
- honors LRN-001 idempotency — unchanged ~/.gitconfig skipped; existing value reused.
- honors LRN-011 — oracle is a stub harness on extracted functions, no live install, no git config.
- honors LRN-014 — bash 3.2 safe.
- Non-binding: BDR-016 (backup naming, kept as is).

## CHALLENGE SUMMARY (round 1 → v2)
- BLOCKER (correctness+robustness): template path at the call site → placeholders deployed
  → closed: deploy_gitconfig takes name/email/autopush; call site passes the resolved
  identity; Case A asserts no placeholder; Case H pins the call site. [gated]
- BLOCKER (simplicity+robustness): `git config … gitflow.*` denied to this session →
  closed: sed read of ~/.gitconfig, harness writes files directly, zero config access.
- MAJOR: loose boolean grammar / fail-open normaliser → superseded by the user spec:
  exact true/false only, re-ask, default true (user correction), invalid preset aborts.
- MAJOR: empty email drops the answer → closed: named in the skip warning.
- MAJOR: hooksPath wiped on redeploy → superseded by the user spec: fixed template line.
- MAJOR: shared scratch HOME → closed: fresh_home per case + guard.
- MINORs: header comment reworded, `@(USER|EMAIL|AUTOPUSH)@` assertion, README:50, README
  wording (precedence + how to switch), call-site grep. Deferred: system-scope shadowing.
- Added by the user spec: fail-closed grep after render (Case B), DOTFILES_ prefix.

## CHALLENGE SUMMARY (confirmation pass, v3 → v4): SOLID, 8 MINOR
- Accepted: preset validated first; non-exact existing value named; positive true/false
  guard + no-pipe leak check; patsub_replacement off + Case A2; err files in scratch HOME;
  Case I in Case A's HOME; harness header + refusal rule; TODO line rewritten.
- Edge-case text corrected (off/no/0 are valid false for the readers).
- BDR-012 deviation (preset abort) flagged in the Disposition.

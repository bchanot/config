# CONTRACT — gitconfig-autopush
- date: 2026-10-07 | flow: feat | branch: develop → feature/gitconfig-autopush
- status: active

## REQUEST (verbatim — IMMUTABLE)
est-ce qu'on deploi un gitconfig ? Oui peut-on faire en sorte de demander a l'installation si on ajoute git config --global gitflow.autopush false ou git config --global gitflow.autopush true . Au choix a l'installation et mis dnas le gitconfig. d'ailleurs on a bien le user et le mail dnas le gitconfig aui sont bien ceux qu'on configure a l'installation ?

## CLARIFICATIONS
Q: Default when Enter is pressed or no terminal is attached? / A: `true` [gated 2026-10-07] — confirmed by the user's correction after the second message ("non pardon je voulais dire defaut true").
Q: Env preset name? / A: `GITFLOW_AUTOPUSH` [gated 2026-10-07] — SUPERSEDED by the user spec: `DOTFILES_GITFLOW_AUTOPUSH`.
Q: install.sh:688 passes the repo template to deploy_gitconfig, so ~/.gitconfig gets `name = @USER@`; fix in this run? / A: yes, deploy_gitconfig takes the resolved name/email/autopush [gated 2026-10-07]
Q: redeploy drops `core.hooksPath` (set by `make link`)? / A: warn + note [gated 2026-10-07] — SUPERSEDED by the user spec: fixed template line `hooksPath = ~/.claude/githooks` in `[core]`, git expands `~`, the installer neither creates nor checks the directory.
Q: how is an existing value read, given `git config … gitflow.*` is denied to this session? / A: sed over ~/.gitconfig, exact true/false reused silently; no git config access in installer or oracle [gated 2026-10-07]
USER SPEC (second message, 2026-10-07, verbatim constraints) [gated 2026-10-07]:
- Question at install: « Push automatique des commits par les hooks gitflow sur cette machine ? [true/false] » default true (corrected from the spec's "défaut : false" by the user's next message). Rendered in English like the other install prompts; wording open to change at the diff review.
- Only the exact values `true` and `false` are accepted; anything else re-asks; empty → `true`.
- The render fails explicitly if `@AUTOPUSH@` remains in the final content (grep after render); nothing written.
- Non-interactive: `DOTFILES_GITFLOW_AUTOPUSH=true|false`, default true. (Orchestrator choice, flagged for the diff review: any other preset value aborts the install at the identity step, before any file is touched.)
- Keep the existing backup `~/.gitconfig.backup-<timestamp>`; no other template section touched.
- No test suite / no --dry-run exists: the oracle harness carries the two requested cases (rendered @AUTOPUSH@, leaked placeholder = failure).
- The user sees the full diff before anything is committed.

## ACCEPTANCE CRITERIA
1. `gitconfig` template: `[gitflow]` section with `autopush = @AUTOPUSH@`, and `hooksPath = ~/.claude/githooks` inside `[core]`; other sections unchanged except the header comment.
   CHECK: grep -q '^\[gitflow\]' gitconfig && grep -q '^    autopush = @AUTOPUSH@' gitconfig && grep -q '^    hooksPath = ~/.claude/githooks' gitconfig && echo GITCONFIG_TEMPLATE_OK
   EXPECT: GITCONFIG_TEMPLATE_OK
   EVIDENCE: MET exit=0 marker-found :: GITCONFIG_TEMPLATE_OK
2. `install.sh` resolves the push mode: an exact `true`/`false` already in ~/.gitconfig wins silently; else `DOTFILES_GITFLOW_AUTOPUSH` (exact true/false; any other value aborts with a message); else a tty prompt accepting only `true`/`false`, re-asking otherwise, Enter = `true`; else `true`.
3. Oracle harness: rendered file carries the resolved autopush, name, email, hooksPath and no placeholder; a leaked `@AUTOPUSH@` makes deploy_gitconfig fail without writing; existing value beats the preset; strict preset; prompt loop; empty email skip; idempotent re-run.
   CHECK: bash .claude/tasks/contracts/check-autopush-render.sh
   EXPECT: AUTOPUSH_RENDER_OK
   EVIDENCE: MET exit=0 marker-found :: AUTOPUSH_RENDER_OK
4. install.sh stays syntactically valid and shellcheck clean.
   CHECK: bash -n install.sh && shellcheck install.sh && echo LINT_OK
   EXPECT: LINT_OK
   EVIDENCE: MET exit=0 marker-found :: LINT_OK
5. README.md (gitconfig row, remote-install question list, install step 6) and CLAUDE.md layout line document the question, the strict values, the env preset, the reuse of an existing value and the fixed hooksPath.
6. Call site passes the resolved identity, never the repo template path.
   CHECK: grep -q 'deploy_gitconfig "\$identity_name" "\$identity_email" "\$autopush"' install.sh && ! grep -q 'deploy_gitconfig "\$SCRIPT_DIR' install.sh && echo CALLSITE_OK
   EXPECT: CALLSITE_OK
   EVIDENCE: MET exit=0 marker-found :: CALLSITE_OK
7. `.githooks/post-commit` and `.githooks/post-merge` are not part of the change (pre-existing session-hook refresh).
   CHECK: git diff --cached --name-only | grep -q '^\.githooks/' && exit 1; echo HOOKS_UNTOUCHED
   EXPECT: HOOKS_UNTOUCHED
   EVIDENCE: MET exit=0 marker-found :: HOOKS_UNTOUCHED

## FILE SCOPE
gitconfig, install.sh, README.md, CLAUDE.md, .claude/tasks/contracts/check-autopush-render.sh (oracle harness, LRN-011 pattern)

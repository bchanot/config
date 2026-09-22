# Evals

Quality check of Claude output. Caveman + English.

## EVAL-001 — install.sh fix verified
2026-05-27. Method: `shellcheck install.sh` (CLEAN) + `bash -n install.sh` (syntax OK).
Not runtime-tested (would mutate ~/.vim, ~/.bashrc on this machine). Logic traced by hand:
SCRIPT_DIR resolution, idempotent clones, target case map all correct. Anomaly: none.
Action: safe to commit. Full runtime test deferred to next clean VM.

## EVAL-002 — install.sh offers (tmp on disk, ssh guard) — stub-verified, live pending
2026-09-22. Method: shellcheck + bash -n CLEAN (install.sh, cloudpex/install.sh); stub harness (LRN-011) ran both
offers through 9 scenarios, emitted sudo calls match design; `systemd-tmpfiles --dry-run` accepts tmp.conf;
`sh -n` on earlyoom env file. NOT run live (sudo). Anomaly: none. Action: user applies runbook, then checks
`findmnt -T /tmp` (no tmpfs), `systemctl status earlyoom`, `systemctl show ssh -p OOMScoreAdjust -p MemoryMin`,
`cloudpex -s` → close this EVAL.

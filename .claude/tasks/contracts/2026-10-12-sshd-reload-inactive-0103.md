# CONTRACT — sshd-reload-inactive
- date: 2026-10-12 | flow: hotfix | branch: bugfix/sshd-reload-inactive
- status: active

## REQUEST (verbatim — IMMUTABLE)
install.sh harden_sshd: `sudo systemctl reload ssh` fails under set -e when ssh.service is not active (WSL, socket-activated or never started) → "ssh.service is not active, cannot reload." aborts the whole install. Fix: reload only if `systemctl is-active --quiet ssh`, otherwise print that the drop-in is in place and applies at the next sshd start. Keep shellcheck clean, tabs.

User message: "ok ca a fonctionne, par contre maintenant je bloque a Deploying sshd hardening drop-in
ssh.service is not active, cannot reload.. je sais pas si c'es tpour installer ssh-server ? Si oui demande aussi pour l'installer, si non il bloque pour quoi ?"

## CLARIFICATIONS
none — request complete (openssh-server is already in the apt list; the block is the unconditional reload)

## ACCEPTANCE CRITERIA
1. Symptom gone: harden_sshd no longer aborts the install when ssh.service is inactive (reload guarded by `systemctl is-active --quiet ssh`, else an informative echo).
2. Build/tests green: `bash -n install.sh` and `shellcheck install.sh` pass; indentation stays tabs.

## FILE SCOPE
install.sh (harden_sshd only)

# PLAN — sshd-reload-inactive (hotfix)

## Root cause
`install.sh` runs under `set -euo pipefail`. `harden_sshd()` (lines ~226-236) ends with an
unconditional `sudo systemctl reload ssh`. On WSL (and any host where sshd is socket-activated
or simply not started) ssh.service is inactive, systemctl prints
"ssh.service is not active, cannot reload." and exits non-zero, so `set -e` aborts the whole
install at "Deploying sshd hardening drop-in". openssh-server itself IS installed (apt list,
line ~730); the drop-in has already been installed and validated with `sshd -t` at that point.

## Exact edit (install.sh, harden_sshd, tabs) — revised after challenge
1. Before `sudo sshd -t`, add one line so the validation also works when ssh.service is
   inactive (privsep dir normally created by the unit's RuntimeDirectory; absent on Ubuntu
   24.04 when sshd never ran — challenge correctness MAJOR + robustness MINOR 2):
```
	sudo install -d -m 0755 /run/sshd
```
2. Replace the unconditional reload
```
	sudo systemctl reload ssh
}
```
with
```
	if systemctl is-active --quiet ssh; then
		sudo systemctl try-reload-or-restart ssh
	else
		echo "ssh.service not running — drop-in in place, applies at the next sshd start"
	fi
}
```
`try-reload-or-restart` exits 0 if the unit stopped between the check and the call
(robustness MINOR 1); the `is-active` guard stays for the informative echo.
3. Update the function's header comment (one or two lines): /run/sshd is created so `sshd -t`
   works without a running sshd; the reload happens only when sshd is running.

## Smoke (robustness MINOR 3 — exercise the else branch for real)
In the scratchpad, extract `harden_sshd` from install.sh into a temp script with
`SCRIPT_DIR` pointing at the repo, prepend a stub dir to PATH where `systemctl` exits 3 for
`is-active` (and 0 otherwise), `sudo` runs its arguments without privilege, `sshd` exits 0;
run under `set -euo pipefail` and assert exit 0 + the "drop-in in place" echo. Then flip the
stub (`is-active` exits 0) and assert `try-reload-or-restart ssh` is what gets called.
Plus `bash -n install.sh` and `shellcheck install.sh`.

## Constraints
- No other change; `offer_ssh_memory_guard` uses `systemctl restart ssh`, which starts an inactive
  unit and is out of scope.
- shellcheck clean, `bash -n` clean, tabs.

## Challenge summary
- correctness MAJOR (/run/sshd missing → sshd -t false reject) → closed by edit 1.
- robustness MINOR 1 (check-then-act race) → closed by `try-reload-or-restart`.
- robustness MINOR 2 (same /run/sshd risk) → closed by edit 1.
- robustness MINOR 3 (gate never runs the else path) → closed by the Smoke section.
- simplicity: SOLID, no findings.

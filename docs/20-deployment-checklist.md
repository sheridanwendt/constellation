# Deployment Checklist

This is the operator's checklist for standing up Constellation on a fresh
machine. It contains **only actions the installer cannot or should not do
for you** — everything else is automated by `platform-install-Ubuntu.sh`
(see [Operations](09-operations.md) for what that covers).

Per `CLAUDE.md`: the installer is the source of truth, and it should get
more complete after every real deployment. If you find yourself doing
something by hand here that a computer could safely decide on its own,
that's a gap — fold it into `scripts/install/` (see
[Installer Feedback Loop](#installer-feedback-loop) below) rather than
just remembering it for next time.

## 1. Ubuntu installation complete

Install Ubuntu Server 24.04 LTS on the target hardware
(`docs/15-resource-planning.md` for the Phase 1 target spec). During the
Subiquity installer, enabling "Install OpenSSH server" is convenient but
not required — `platform-install-Ubuntu.sh` will install and enable it
itself if it's missing (see ADR-0005).

**Automated:** package upgrades, prerequisites, SSH install/config, Docker,
directories, configuration, deployment, and health verification all happen
in one command in step 7 below.

## 2. Verify SSH access

Confirm you can reach the machine before doing anything else:

```bash
ssh <user>@<server-ip>
```

If you have physical/console access, compare the host key fingerprint
against what the console shows on first boot. After running the installer,
`scripts/install/02-ssh.sh` prints the host's SSH key fingerprints again
for the same out-of-band comparison on future connections.

This is a manual step because verifying *you're actually talking to your
own machine* (not a MITM) inherently requires an independent, human-owned
channel — the installer can't attest to its own trustworthiness.

## 3. Optional: VM snapshot / Clonezilla image

If this is a VM, or you have imaging tooling available, take a
known-good snapshot/image now, before making any changes.

This is explicitly a human judgment call (per `CLAUDE.md`/the Phase 1
installer review) — whether it's worth the time/storage depends on your
hardware, how easy a from-scratch reinstall is for you, and how much you
trust the installer's idempotency. The installer will never decide this
for you or take a snapshot on its own.

## 4. Clone the repository

```bash
sudo apt-get update && sudo apt-get install -y git   # only if git isn't already present
git clone <this-repo-url> constellation
cd constellation
```

Clone anywhere convenient — you don't need to clone directly to
`/opt/constellation`. The installer normalizes the install location itself
(step 7 below; see [ADR-0006](adr/0006-canonical-install-location.md)),
so wherever you clone to here is only a staging point, not the final
install path.

This step itself can't be automated by `platform-install-Ubuntu.sh`
because the installer lives *inside* the repository you're about to
clone — there's nothing to run yet.

## 5. Verify repository state

```bash
git status
git log -1 --oneline
git branch --show-current
```

Confirm you're on the branch/tag you intend to deploy and the working tree
is clean, especially if this checkout is being reused rather than freshly
cloned. A human should always be the one deciding "this is the code I want
to run" before it's executed as root.

## 6. Review the installer

Before running anything as root, skim `platform-install-Ubuntu.sh` and
`scripts/install/*.sh` — especially if this is a fork, a branch you didn't
write, or it's been a while since you last read them.

```bash
less platform-install-Ubuntu.sh
ls scripts/install/
```

Trusting root-level automation is a judgment call every time, not a
one-time decision — the installer can't vouch for itself.

## 7. Run the installer

```bash
sudo ./platform-install-Ubuntu.sh
```

This one command now runs, in order: relocate to the canonical install
location (`/opt/constellation`) if not already there, an `initial` backup
checkpoint, pre-flight validation, package updates/prerequisites, SSH
install/config, Docker, directories, self-validated `.env` generation, a
`dependencies` backup checkpoint, deployment, protocol-level health
verification, enabling the weekly backup timer, and a final
`constellation` backup checkpoint. See
[Operations](09-operations.md#fresh-install) for the full breakdown of
what each step does.

If it relocates, you'll see it copy itself to `/opt/constellation` and
re-run from there automatically — that's expected, not an error; just note
that `/opt/constellation` (not your original clone) is where the
platform actually lives from here on.

It fails fast: if any step fails, everything after it is skipped rather
than attempted, and the run ends with a summary showing exactly what
happened (see [Operations § Deployment Summary](09-operations.md#deployment-summary--status-framework)).
If you see `Overall: FAIL`, don't proceed to the next checklist step —
fix what the summary points at and re-run; it's safe to re-run.

## 8. Validate services

The installer already waits for container health, confirms the
containers it started actually exist, and runs real protocol-level
checks (`scripts/install/07-verify.sh`) before it reports success — and
its summary tells you plainly whether that succeeded. As an operator,
still take a look yourself:

```bash
./scripts/status.sh
./scripts/doctor.sh   # deeper, read-only diagnostic - same report format
```

Automation can confirm the services answer; only a human can confirm
they're the *right* services doing the *right* thing for your use case.

## 9. Enable the installer feedback loop

```bash
sudo ./scripts/audit-enable.sh
```

Do this once, right after a successful install. See
[Installer Feedback Loop](#installer-feedback-loop) below — this can't be
automated because it needs to run *after* you've confirmed the install
succeeded, and its whole purpose is capturing what *you* do next.

## 10. Verify reboot behavior

Reboot the machine and confirm everything comes back on its own:

```bash
sudo reboot
# after it comes back:
./scripts/status.sh
systemctl status constellation-backup.timer
```

`docker-compose.yml` uses `restart: unless-stopped` and `docker`/`ssh` are
both `systemctl enable`d by the installer, so this should require zero
manual intervention — but actually rebooting a physical machine and
watching it come back is inherently something only an operator can do
(and should do, at least once per real deployment, per the Phase 1
review). If step 1's package upgrade flagged
`/var/run/reboot-required`, this is also when that gets cleared.

## 11. Backup recommendations

The installer already took three named checkpoint backups during install
(`initial`, `dependencies`, `constellation` — see
[Operations § Fresh Install](09-operations.md#fresh-install)) and enables
weekly automated backups (`constellation-backup.timer`) by default — no
separate step needed. What remains manual, by design:

- **Off-host copy.** `backups/` lives on the same disk as everything else.
  Periodically copy it somewhere durable (another machine, external drive,
  object storage) — *where* is a decision about your own infrastructure
  the installer has no way to make for you.
- **Restore drills.** There is no restore automation yet (Phase 2+); if a
  backup matters, periodically confirm you can actually restore from it.

See [Operations § Backups](09-operations.md#backups) for the retention
policy and what's included in each backup.

## 12. Upgrade workflow

Not yet automated (tracked for a later phase — see
`docs/09-operations.md#future-operational-tools`). Until then, run this
against the canonical install (`/opt/constellation` by default, not your
original clone location if they differ):

```bash
cd /opt/constellation
git status                    # confirm a clean tree first
git fetch origin
git log HEAD..origin/main --oneline   # see what's changing
git pull
sudo ./platform-install-Ubuntu.sh     # idempotent - safe to re-run
./scripts/status.sh
```

Every `scripts/install/*.sh` step is written to be safely re-runnable, so
re-running the full installer after a `git pull` is the supported upgrade
path today. Deciding *when* to upgrade, and reviewing what changed first,
stays a human call.

---

## Installer Feedback Loop

The command-audit tools (`scripts/audit-enable.sh`,
`scripts/audit-review.sh`, `scripts/audit-disable.sh`) are how manual
fixes made directly on a running host get folded back into the installer,
instead of being silently lost the next time someone rebuilds from
scratch. See [README § Installer Feedback Loop](../README.md#installer-feedback-loop)
for the full explanation, and
[Operations § Keeping the Installer as Source of Truth](09-operations.md#keeping-the-installer-as-source-of-truth)
for the mechanics.

Workflow:

1. After a successful install: `sudo ./scripts/audit-enable.sh` (step 9
   above).
2. Administer the box normally — every interactive shell command is
   captured to `logs/command-audit.log`.
3. Periodically: `./scripts/audit-review.sh` — filters out routine/noise
   commands, dedupes, and suggests which `scripts/install/*.sh` a
   candidate likely belongs in.
4. For each candidate, decide: fold it into `scripts/install/` (or another
   automation script) and re-run the installer end-to-end to confirm it's
   idempotent, or consciously discard it as one-off/exploratory.

This is deliberately a human-in-the-loop review, not an auto-apply
mechanism — see [Architecture Validation](#architecture-validation) below
for why that matters.

## Architecture Validation

Checklist for confirming this deployment still upholds the Phase 1
architecture (`CLAUDE.md`):

- [ ] `platform-install-Ubuntu.sh` remains the single source of truth —
      nothing required to rebuild the platform lives only in someone's
      memory or shell history.
- [ ] The deployment is reproducible — a second run of the installer on
      the same or a fresh machine produces the same result.
- [ ] The install lands in the same place every time
      (`/opt/constellation` by default) regardless of where it was cloned
      or run from.
- [ ] A failure stops the installer immediately and shows up clearly in
      the deployment summary — never a silent, unexplained crash.
- [ ] Manual steps are limited to what's in this document; anything else
      done by hand is a signal to update the installer (via the feedback
      loop) or this checklist.
- [ ] README.md and this document agree with what the scripts actually do.
- [ ] The installer feedback loop is being used to *close the loop* back
      into `scripts/install/` — not as a substitute for automation, and
      not as an unreviewed auto-apply path. Every fold-in still goes
      through a human decision and a normal code change.

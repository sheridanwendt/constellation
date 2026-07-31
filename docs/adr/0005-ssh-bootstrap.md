# ADR-0005: Installer-Managed SSH Bootstrap

Status:

Accepted


# Decision

`platform-install-Ubuntu.sh` (via `scripts/install/02-ssh.sh`) manages SSH on
the target host as part of every install:

- Ensures `openssh-server` is installed, enabled, and running.
- Explicitly sets `PasswordAuthentication yes` and `PubkeyAuthentication yes`
  via an `/etc/ssh/sshd_config.d/` drop-in, validated with `sshd -t` before
  reload.
- Generates a dedicated automation/deploy key pair at
  `/etc/constellation/ssh/deploy_ed25519`, for future non-interactive/service
  use (e.g. CI, host-to-host automation). Not authorized for login anywhere
  by default.
- Generates a personal login key pair for the operator running the
  installer (`~/.ssh/id_ed25519` under `$SUDO_USER`, if one doesn't already
  exist) and adds its public key to that user's `~/.ssh/authorized_keys`.
- Prints host key fingerprints for out-of-band verification on first
  connect.

All of the above is idempotent and safe to re-run.


# Reasoning

Per CLAUDE.md, "anything required to rebuild a working platform from a
fresh Ubuntu installation must be automated." Installing and wiring up SSH
is one of those things every deployment does, so it belongs in the
installer rather than being repeated by hand each time (see
`docs/20-deployment-checklist.md`).


# Explicit Non-Goal: SSH Hardening

The installer deliberately does **not** disable password authentication or
otherwise narrow how you can log in. It only ever adds a login method
(a key), never removes one.

This is a hard boundary, not an oversight:

- The installer's own earlier design review flagged that generating a
  server-side key and then flipping the host to key-only auth in the same
  run creates a real lockout risk if that key is lost, misconfigured, or
  never copied off the box before password auth is disabled remotely.
- The target hardware in Phase 1 (`docs/15-resource-planning.md`) is a
  single physical machine an operator may be administering remotely with no
  physical console handy; an unrecoverable SSH lockout there means a trip
  to the machine, not a support ticket.
- Hardening (key-only auth, disabling passwords) is a security decision
  that depends on operator context the installer cannot see: is a key
  already deployed to a trusted client, is there console/IPMI access as a
  fallback, is this host reachable only from a private network already.
  That is exactly the kind of human judgment call CLAUDE.md and the
  Phase 1 installer-improvement review (2026-07) call out as something the
  installer should not automate on its own.

If/when host hardening is wanted, it should be a separate, explicit,
operator-initiated step (own script, own confirmation prompt) — not a side
effect of a routine reinstall.


# Key Storage

| Key                     | Location                              | Purpose                                    |
|--------------------------|----------------------------------------|---------------------------------------------|
| Deploy/automation key    | `/etc/constellation/ssh/deploy_ed25519` (+ `.pub`) | Future non-interactive/service use. System-scoped, not tied to the git checkout, survives a repo re-clone. |
| Operator login key       | `~/.ssh/id_ed25519` under the invoking user | Personal interactive login; added to that user's own `authorized_keys`. |

Both are `ed25519`, generated with no passphrase (matching the
non-interactive install flow), and excluded from git and from
`scripts/backup.sh`'s config archive — they live outside the repo tree
(`/etc/constellation/ssh/`) or in the operator's own home directory, never
under the Constellation checkout.

The operator login key is generated on the server itself, which is a
weaker security posture than the usual client-generated-key flow (the
private key exists on the server, if only briefly). The installer prints a
reminder to copy it off-host and delete the local copy if the operator
wants the standard posture; password login remains available in the
meantime specifically so this isn't a forced tradeoff.


# Future

A separate, explicitly operator-invoked hardening script (disable password
auth, restrict to specific keys) may be added later. It must not be folded
into the default install path.

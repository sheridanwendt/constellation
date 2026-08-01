# Project Plan

## Phase 1 - Infrastructure Foundation

Build:

- Ubuntu installation scripts
- Docker installation
- Docker Compose
- PostgreSQL
- Qdrant
- NATS


---

## Phase 2 - Platform Core

Build:

- Event contracts
- Memory API (Platform / User / Agent memory - see `docs/12-memory-model.md`)
- Skill API
- Agent registry
- Permissions model (agent capabilities; single shared API key for
  service auth in this phase - real per-agent service identity is
  Phase 7, see ADR-0008 note below)
- Configuration & health endpoints (backend only - the operator-facing
  UI for these lands in Phase 4, see below)

Architecture: `platform-core` is a single modular-monolith service
(Memory / Skill routing / Agent Registry / Permissions as internal
modules, not separate services); individual skills are their own
containers. See [ADR-0008](adr/0008-phase2-modular-monolith.md).


---

## Phase 3 - First Agent

Implement:

- Hermes adapter
- Agent lifecycle
- Agent communication


---

## Phase 4 - Connectors

Add:

- Telegram
- Discord
- Web UI - a single web app serving both end users and platform
  operators as permission-gated views of the same UI, not two separate
  apps. Built incrementally: operator/monitoring views (platform health,
  configuration) land as soon as Phase 2's backend exists, ahead of any
  agent being available; end-user chat views are added once Phase 3
  delivers the first agent.
- Email
- Voice


---

## Phase 5 - Additional Agents

Add:

- Athena
- ElizaOS


---

## Phase 6 - Distributed Future

Explore:

- Multiple servers
- GPU workers
- Cloud agents
- Managed infrastructure


---

## Phase 7 - Service Identity & Auth Hardening

Build:

- Real per-agent service identity, replacing Phase 2's shared API key
- NATS/Postgres/Qdrant service authentication (none exists as of Phase 1
  - Postgres has only its connection password, NATS has none)
- Service-to-service auth (e.g. mTLS or signed tokens) between
  `platform-core`, skill services, and agent adapters

Numbered after Phase 6 to avoid renumbering the existing phases, but
logically a prerequisite for any real Phase 6 distributed deployment -
don't run agents across multiple machines on the Phase 2 shared-key
placeholder.

---

# Phase Dependency Clarification

Platform capabilities must exist before advanced agent integrations.

Before implementing multiple agents:

Complete:

- Event contracts
- Memory API
- Skill API
- Agent Registry
- Permission model

Then integrate:

- Hermes
- Athena
- ElizaOS

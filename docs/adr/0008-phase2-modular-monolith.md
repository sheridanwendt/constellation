# ADR-0008: Phase 2 Platform Core as a Modular Monolith

Status:

Accepted


# Decision

`platform-core` (Memory, Skill routing, Agent Registry, Permission
checking) is **one process, one container**, internally split into
Python modules with clean interfaces between them - not one service per
capability.

Individual **skills** (web-search, filesystem, browser, etc.) are the
exception: each gets its own container/service from the start, per
`docs/16-skill-contract.md`'s own example structure
(`skills/web-search/skill.yaml` + `service/`), since skills are the most
likely place for wildly different dependencies (headless browsers,
filesystem mounts, third-party credentials) and the most likely target
for isolated/experimental contributions later.

**Modules within `platform-core` communicate via direct in-process
function/method calls - never HTTP, even internally.** A `MemoryStore`
interface (Python `Protocol`/ABC) is injected into whatever needs it
(e.g. the Skill module calling `memory.write(...)`); it is a plain method
call, not a request to an internal URL.


# Reasoning

Weighed against a one-service-per-capability split (Memory API, Skill
API, Agent Registry, Permission service as four separate containers):

- **Resource cost.** Each additional process pays its own Python
  interpreter + Uvicorn/FastAPI baseline (~50-150MB idle) and its own
  Postgres connection pool. Four services doing what one process could do
  is roughly 2-4x the memory and 3-4x the reserved Postgres connections,
  for identical functionality, on hardware also expected to run "one
  agent runtime" per `docs/15-resource-planning.md`.
- **Debuggability.** A request that spans Memory + Registry + Permission
  is one process, one log stream, one stack trace in a monolith. Split
  across services, reconstructing what happened requires distributed
  tracing - which doesn't exist yet (`docs/14-event-model.md` lists
  retries/idempotency/dead-letter/observability as explicit *future*
  work, not built).
- **Replaceability doesn't require process boundaries.** The
  "Migration Question" in `docs/07-development-guidelines.md` ("could
  this be replaced without changing the rest of the system?") is answered
  by a clean *interface*, not a network boundary. A `MemoryStore`
  interface that's the only thing touching Postgres/Qdrant directly is
  exactly as swappable inside a monolith as it would be as a separate
  service - the module boundary is what buys replaceability, not the
  process boundary.
- **No current driver for splitting.** Independent scaling, independent
  deploy cadence, and multiple contributors working in parallel are the
  usual reasons to pay the microservices cost - none apply to a
  single-operator, single-box Phase 2 deployment. That changes in Phase 6
  (Distributed Future), which is the natural point to actually extract
  services, not before.


# The Mistake This Guards Against

It is possible to build something that *looks* like a modular monolith
but silently reintroduces every cost this decision exists to avoid: give
each module its own internal ASGI sub-app/router and have other modules
call it over HTTP (even on localhost, even within the same process
group). That brings back per-call socket/TCP overhead, JSON
serialization on both ends, and - if each "module" opens its own DB
pool - the exact connection multiplication a real service split would
cause. It also buys none of a real service split's benefits (no
independent deployability, no fault isolation, since it's still one
container that lives or dies together).

**Rule:** if a module needs to call another module, it takes a
constructor/dependency-injection reference to that module's interface and
calls it directly. If a module later has a real, concrete reason to
become independently deployable (scaling, deploy cadence, ownership), that
is a deliberate extraction with its own ADR - not something to
half-do via an internal HTTP call today.


# Consequences

- `platform-core`'s internal layout should be organized by module
  (`memory/`, `skills/`, `registry/`, `permissions/`) with interfaces
  defined at the boundaries, from the first line of code - retrofitting
  clean boundaries after the fact is far more expensive than starting
  with them.
- Skills remain independently deployable/replaceable by construction
  (`docs/16-skill-contract.md`'s design rule: "Skills should be
  replaceable without modifying agents") without `platform-core` itself
  needing to be split.
- Extracting any `platform-core` module into its own service later
  (Phase 6+) should be possible without touching the modules that didn't
  move, provided the interface discipline above is maintained.

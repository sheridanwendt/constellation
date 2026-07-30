# Design Principles

## Modularity

Each component should have clear responsibilities and boundaries.

Constellation should be composed of replaceable modules rather than one monolithic application.

---

## Replaceability

Components should be replaceable without redesign.

Examples:

PostgreSQL -> Supabase

Qdrant -> Managed vector database

Local agents -> Cloud agents

Docker Compose -> Future orchestration systems

---

## Event Driven Communication

Components communicate through standardized events.

Examples:

- message.received
- task.created
- task.completed
- memory.updated
- agent.status.changed

Agents should subscribe and publish events rather than directly calling each other.

---

## Infrastructure Abstraction

Agents should not know:

- database implementations
- deployment location
- user interface details
- infrastructure providers

Agents interact through platform services.

---

## Shared Capabilities

Skills belong to the platform, not individual agents.

Examples:

- Search
- Browser automation
- Filesystem access
- Email
- Calendar
- MCP tools
- External APIs

---

## Composition Over Modification

New functionality should generally be added through:

- New agents
- New skills
- New connectors
- New adapters

Avoid modifying the core platform for every new capability.

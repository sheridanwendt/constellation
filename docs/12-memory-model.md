# Memory Model

Memory is provided through a platform abstraction.

Agents never communicate directly with storage.

---

# Memory Types

## Platform Memory

Shared knowledge.

Examples:

- documents
- projects
- organizational knowledge


## User Memory

User-specific information.

Examples:

- preferences
- history
- settings


## Agent Memory

Private agent state.

Examples:

- workflow state
- internal context
- learned preferences

---

# Storage

Operational:

PostgreSQL

Semantic:

Qdrant

Future migration:

Supabase PostgreSQL + pgvector

---

# Principle

Memory ownership and permissions must be explicit.

No agent should automatically have access to all memory.

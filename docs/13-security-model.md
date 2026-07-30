# Security Model

Agents should be treated as independent services.

Trust boundaries must exist between agents, skills, and data.

---

# Permissions

Permissions determine:

- which skills an agent can use
- what data an agent can access
- what actions an agent can perform

---

# Skill Access

Example:

Agent

↓

Permission Check

↓

Skill Service

↓

External Resource

---

# Secrets

Initial approach:

- environment variables
- Docker secrets

Future:

- encrypted secret storage
- Vault integration

---

# Principle

No agent should have unrestricted access to all platform capabilities.

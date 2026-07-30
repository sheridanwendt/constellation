# Agent Model

An agent is an independent execution unit.

Agents may use different frameworks.

Examples:

- Hermes
- Athena
- ElizaOS

---

# Agent Definition

Each agent should provide a manifest.

Example:

agent.yaml

name:

framework:

version:

capabilities:

skills:

subscriptions:

publishes:

resources:

---

# Agent Registry

The registry stores:

- Agent identity
- Framework
- Version
- Capabilities
- Skills
- Events
- Resource requirements

---

# Agent Rules

Agents:

- communicate through platform services
- do not access databases directly
- do not directly control connectors
- do not directly invoke other agents

Collaboration happens through Constellation services.

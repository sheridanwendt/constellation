# Agent Registry

The Agent Registry tracks available agents in Constellation.

The registry is stored in PostgreSQL.


# Registration

Agents register when starting.

Example:

    POST /platform/agents/register


# Agent Manifest Example

    name: hermes

    framework: hermes

    version: 1.0

    skills:
      - memory.read
      - memory.write
      - web.search

    subscriptions:
      - message.received

    publishes:
      - response.generated


# Registry Stores

- Agent identity
- Framework
- Version
- Capabilities
- Skills
- Event subscriptions
- Resource requirements
- Health state


# Discovery

Services query the registry to discover:

- Available agents
- Agent capabilities
- Agent status


# Rule

Agents do not discover each other directly.

Discovery occurs through Constellation services.

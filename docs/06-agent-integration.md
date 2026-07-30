# Agent Integration

Agents integrate through adapters.

The platform should not depend on framework internals.

Example:

Hermes

↓

Hermes Adapter

↓

Platform Services


Adapters handle:

- Event translation
- Lifecycle management
- Skill access
- Memory access

Do not modify external frameworks unless necessary.

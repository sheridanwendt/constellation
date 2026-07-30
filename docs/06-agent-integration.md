# Agent Integration

Agents integrate through adapters.

Constellation should never become dependent on a specific agent framework.

---

## Adapter Responsibilities

Adapters handle:

- Framework lifecycle
- Input translation
- Output translation
- Event publishing
- Skill access
- Memory access


---

## Example

Hermes

↓

Hermes Adapter

↓

Constellation Platform


---

## Rules

Agents should not:

- directly access databases
- directly access Telegram
- directly access other agents
- directly manage infrastructure

The adapter provides the boundary.

---

## Adding New Frameworks

Adding a new agent framework should generally require:

1. Creating an adapter
2. Creating deployment configuration
3. Registering capabilities
4. Defining event subscriptions

The core platform should remain unchanged.

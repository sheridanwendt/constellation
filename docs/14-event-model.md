# Event Model

Events are the primary asynchronous communication method.

---

# Event Categories

## User Events

Examples:

- user.message.received
- user.voice.received


## Agent Events

Examples:

- agent.started
- agent.completed


## Task Events

Examples:

- task.created
- task.failed


## Memory Events

Examples:

- memory.created
- memory.updated


---

# Reliability Requirements

Future implementations should support:

- retries
- idempotency
- correlation IDs
- dead letter handling
- observability

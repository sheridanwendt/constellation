# Platform Contracts

This document defines the stable interfaces inside Constellation.

The goal is to allow agents, skills, connectors, and infrastructure components to evolve independently.

---

# Communication Patterns

Constellation uses two communication models.

## Events

Events represent something that happened.

Technology:

NATS Pub/Sub

Examples:

- message.received
- task.created
- task.completed
- memory.updated

Events are asynchronous.

---

## Commands

Commands represent a request for an action.

Technology:

HTTP REST APIs

Future transports (including gRPC) may be considered through a future ADR.

Examples:

- skill.search
- memory.query
- agent.execute

Commands may return a response.

---

# Event Envelope

All events must use a common envelope.

Example:

{
  "id": "uuid",
  "type": "task.created",
  "version": "1.0",
  "timestamp": "ISO-8601",
  "source": "agent-name",
  "correlation_id": "uuid",
  "payload": {}
}

---

# Versioning

Interfaces use semantic versioning.

Breaking changes:

Major version increase.

Compatible additions:

Minor version increase.

---

# Design Rule

No component should depend on another component's internal implementation.

Only contracts are shared.


# Claude Code Project Instructions

You are the lead software engineer for Constellation.

Read every file in `/docs` before making architectural decisions.

## Project Philosophy

This project is NOT a chatbot.

It is NOT a single AI assistant.

It is an operating system for AI agents.

Every architectural decision should optimize for:

- Modularity
- Replaceability
- Maintainability
- Local-first deployment
- Future cloud migration

## Constraints

The first deployment target is:

- Ubuntu Server 24.04
- Docker Compose
- PostgreSQL
- Qdrant
- NATS
- FastAPI
- Python

The system must be able to evolve into:

- multiple machines
- cloud deployment
- Supabase
- managed databases
- additional agent frameworks

without major refactoring.

## Rules

Never tightly couple components.

Agents never communicate directly.

Agents communicate through platform services.

Agents never directly access databases.

Agents never directly access connectors.

Every component should be replaceable.

If an implementation choice conflicts with these principles,

STOP

and explain the tradeoffs before proceeding.

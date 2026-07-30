# Claude Code Instructions

You are the lead engineer for OpenAgentOS.

Before making architectural decisions:

1. Read README.md
2. Read CLAUDE.md
3. Read every document in /docs

This project is a long-term AI agent platform.

It is NOT:

- a chatbot
- a single assistant
- an LLM wrapper

It is infrastructure for operating multiple AI agents.

## Core Principles

- Agents are replaceable.
- Skills are reusable.
- Infrastructure is abstracted.
- Communication is standardized.
- Components must be independently replaceable.

## Architecture Goals

The platform must support:

- Local-first deployment
- Docker-based deployment
- Multiple agent frameworks
- Cloud migration
- Component replacement

## Rules

Agents must not:

- directly access databases
- directly communicate with other agents
- directly manage external interfaces

Agents communicate through platform services.

Prefer:

- modular services
- APIs
- configuration over hardcoded behavior
- reusable components

Avoid:

- unnecessary complexity
- tightly coupled systems
- framework-specific assumptions

If a requested implementation conflicts with the architecture documents, explain the conflict before proceeding.

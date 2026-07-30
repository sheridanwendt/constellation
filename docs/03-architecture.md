# Architecture

## Overview

Constellation is a collection of modular services communicating through stable interfaces.

High-level flow:

Users

↓

Connectors

↓

API Gateway

↓

Event Bus

↓

Agents / Skills / Memory


---

# Core Components

## API Gateway

Technology:

FastAPI

Responsibilities:

- External API access
- Authentication
- Request routing
- Web interfaces


---

## Event Bus

Technology:

NATS

Responsibilities:

- Agent communication
- Async workflows
- Event routing


Example events:

- message.received
- task.created
- task.completed
- response.generated


---

## Agent Runtime

Agents run as independent services.

Initial supported frameworks:

- Hermes
- Athena
- ElizaOS

Agents integrate through adapters.

The platform should not depend directly on framework internals.


---

## Agent Adapters

Adapters translate between external frameworks and Constellation services.

Example:

Hermes

↓

Hermes Adapter

↓

Constellation Events

Constellation Skills

Constellation Memory


---

## Skills

Shared reusable capabilities.

Examples:

- Filesystem
- Search
- Browser
- Email
- GitHub
- MCP tools


---

## Memory

Memory is accessed through an abstraction layer.

Operational storage:

PostgreSQL

Used for:

- Users
- Tasks
- Configurations
- Jobs


Semantic storage:

Qdrant

Used for:

- Documents
- Embeddings
- Semantic retrieval


Future migration:

Supabase PostgreSQL + pgvector

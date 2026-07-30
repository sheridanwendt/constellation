# Architecture

## High Level

Users

↓

Connectors

↓

API Gateway

↓

Event Bus

↓

Agents / Skills / Memory


## Core Services

## API Gateway

FastAPI service providing external access.

## Event Bus

NATS provides communication between components.

## Agents

Independent services.

Examples:

- Hermes
- Athena
- ElizaOS

## Skills

Reusable capabilities:

- Search
- Browser
- Filesystem
- Email
- MCP

## Memory

Memory abstraction layer.

Operational database:

PostgreSQL

Vector database:

Qdrant

Future:

Supabase + pgvector

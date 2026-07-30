# Design Principles

## Modularity

Each component should have clear responsibilities.

## Replaceability

Components should be replaceable without redesign.

Examples:

PostgreSQL -> Supabase

Qdrant -> Managed vector database

Local agents -> Cloud agents

## Event Driven

Components communicate through events.

Examples:

message.received

task.created

task.completed

memory.updated

## Abstraction

Agents should not know:

- Database implementations
- Deployment location
- User interface details

## Composition

Add functionality through:

- New agents
- New skills
- New connectors
- New adapters

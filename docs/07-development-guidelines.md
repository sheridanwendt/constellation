# Development Guidelines

## Before Implementing

Review:

- Vision
- Architecture
- Technology decisions
- Project plan


---

## Prefer

- Clear interfaces
- Small modules
- Configuration driven behavior
- Documentation
- Tests


---

## Avoid

- Tight coupling
- Hardcoded dependencies
- Framework-specific assumptions
- Premature optimization


---

## Migration Question

For every major decision ask:

"Could this component be replaced later without changing the rest of the system?"

If not, improve the abstraction.

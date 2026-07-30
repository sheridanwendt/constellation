# ADR-0004: HTTP Command Transport

Status:

Accepted


# Decision

Constellation uses:

Events:

    NATS


Commands:

    HTTP REST APIs


# Reasoning

HTTP is preferred initially because:

- FastAPI native
- Easy debugging
- Simple local development
- MCP compatible
- Appropriate for current scale


# Future

Alternative transports may be introduced internally if scale requires them.

The conceptual command contract should remain unchanged.

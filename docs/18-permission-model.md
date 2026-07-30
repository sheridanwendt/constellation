# Permission Model

Constellation uses capability-based permissions.

Agents are not trusted by default.


# Permission Flow

Agent

    |

Permission Check

    |

Skill Service

    |

External Resource


# Permissions Define

- Which skills an agent can use
- Which resources a skill can access
- Which actions are allowed


# Example

Agent:

    hermes


Allowed:

    memory.read

    memory.write

    web.search


Not allowed:

    filesystem.delete


# Storage

Initial implementation:

PostgreSQL permission tables.


Example:

    agent_permissions

    agent_id

    capability

    scope


# Principle

No agent receives unrestricted platform access.

# Skill Contract

Skills are reusable platform capabilities.

Skills are implemented as independent services.

Agents do not directly access external systems.

Agents request capabilities through the Constellation Skill Service.


# Skill Responsibilities

A skill provides:

- A defined capability
- A manifest
- An API contract
- Permission requirements
- Input validation
- Output formatting


# Skill Structure

Example:

    skills/
        web-search/
            skill.yaml
            service/


# Skill Manifest Example

    name: web.search

    version: 1.0

    description: Search the internet

    inputs:
      query:
        type: string
        required: true

    permissions:
      - network.internet


# Invocation

Skills use HTTP commands.

Example:

    POST /platform/skills/{skill-name}/run


# Request Example

    {
      "request_id": "uuid",
      "agent_id": "hermes",
      "input": {
        "query": "AI news"
      }
    }


# Response Example

    {
      "request_id": "uuid",
      "status": "success",
      "output": {}
    }


# Design Rule

Skills should be replaceable without modifying agents.

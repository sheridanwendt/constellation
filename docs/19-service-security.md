# Service Security

Constellation has two security layers.


# Layer 1: Service Identity

Services authenticate with infrastructure.

Examples:

- NATS
- PostgreSQL
- Qdrant


This protects platform infrastructure.


# Layer 2: Agent Capabilities

Agent permissions determine what actions an agent may perform.


Example:

Hermes requests:

    email.send


Permission service evaluates:

    Allowed

or

    Denied


# Initial Approach

Start simple:

- Docker secrets
- Environment variables
- Internal service credentials


Future options:

- SOPS
- Hashicorp Vault
- Cloud secret managers

# ADR-0001: Use NATS

Status:

Accepted

Decision:

Use NATS as the initial event system.

Reasons:

- lightweight
- local friendly
- supports pub/sub
- supports request/reply
- cloud compatible

Alternatives:

- Kafka
- RabbitMQ
- Redis Streams

Rejected because:

They introduce additional operational complexity at this stage.

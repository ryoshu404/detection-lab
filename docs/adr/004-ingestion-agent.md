# ADR-004: Telemetry Ingestion via Elastic Agent + Fleet

- Date: 2026-07-13
- Deciders: R. Santos
- Supersedes: Filebeat CloudTrail ingestion for the AWS path.

## Status

Accepted

## Context

CloudTrail was ingested via the Filebeat AWS module, which writes a `filebeat-*` index missing `data_stream.dataset` — the field pySigma's Elasticsearch pipelines (and prebuilt rules) target. Since the lab compiles Sigma to Elastic via pySigma, and the endpoints are going on Elastic Agent + Fleet anyway, keeping beats for AWS would mean two schemas and two paradigms to support.

### Decision Drivers

- One canonical-ECS schema so Sigma rules compile against pySigma's stock pipelines without a custom bridge.
- One paradigm across AWS and endpoints, keeping the deploy step's pipeline config uniform.
- Fleet's central policy management and in-place agent upgrades, which beats lacks.

### Considered Options

- Keep Filebeat for AWS, Agent for endpoints (hybrid) — rejected: two schemas, a custom pipeline, dual paradigm.
- Elastic Agent + Fleet for everything — chosen.

## Decision

CloudTrail moved to Elastic Agent (AWS CloudTrail integration, S3 input in SQS mode), reusing the `filebeat-local` IAM keys and SQS queue.

Fleet Server runs in its own Terraform-provisioned Proxmox LXC (`fleet`, 192.168.1.12): unprivileged, native Agent install (TAR, so it's Fleet-upgradable), one agent doing both Fleet Server and AWS collection. It's separate from the Elastic VM to keep it off a swap-disabled, memory-tight host where an OOM could kill Elasticsearch.

Filebeat was stopped and disabled. SQS delivers each message once, so the cutover is forward-only: old events stay in `filebeat-*`, new events flow to `logs-aws.cloudtrail-*`.

## Consequences

CloudTrail now lands as canonical ECS in `logs-aws.cloudtrail-default`, so Sigma rules compile against one schema shared with the endpoints. Costs: a small always-on Fleet LXC (~2 GB) that runs systemd `degraded` under the unprivileged nesting restriction (cosmetic). The retired Filebeat work proved the S3/SQS pipeline and scoped IAM the Agent reuses. GuardDuty ingestion is deferred (separate integration).

# ADR-001: SIEM Platform Selection

- Date: 2026-05-25
- Deciders: R. Santos

## Status

Accepted

## Context

The detection lab needs a primary SIEM to ingest telemetry from multiple sources: AWS CloudTrail, VPC Flow Logs, GuardDuty findings, and, later, endpoint logs. It also needs to serve as the platform where detections are authored, validated, and tuned. All detection rules will be written in Sigma as the portable source format, with compilation to platform-specific languages as a stated goal. The SIEM is one concrete target among several rather than a lock-in.

The choice is constrained by sustained-operation costs, single operator, and the need for the platform to support the full ingestion, parsing, detection, and tuning workflow from end to end. One platform must be selected for primary operation.

### Decision Drivers

- Full control of the ingestion-to-detection pipeline.
    - A detection lab needs visibility into and control over every stage (ingestion, parsing, index and retention management, query, alerting) because meaningful tuning and lifecycle work depend on operating the parts a managed service abstracts away.
- Be able to test that Sigma compiles into working detections.
    - Rules are written in Sigma and compiled into each SIEM's query language; ES|QL is one of them. Because the lab runs on Elastic, the compiled ES|QL is then tested against real data for validation.
- Cost
    - No license cost; main expenditure will be limited to EC2 and EBS.

### Considered Options

- Self-hosted Elastic on EC2 - chosen
- Microsoft Sentinel
- Splunk CE

## Decision

For this project, we will be utilizing self-hosted Elastic on EC2. It gives us full operational control of the pipeline, serves as a directly-validatable compilation target, and fits the cost ceiling.

Microsoft Sentinel was initially the SIEM of choice, and still is a viable choice based on the decision drivers above, but ultimately, was decided against since the value in learning another query language (ES|QL) provided enough merit as I already am fluent in KQL and have experience writing rules/threat hunt queries in KQL.

Splunk CE was disqualified due to lack of features such as alerting and authenticated logins.

## Consequences

Operating the SIEM falls entirely onto us. We will be responsible for patching, upgrading, hardening, and health-monitoring of Elasticsearch, Kibana, and Filebeat. The deployment is single-node, so an instance or volume failure will halt ingestion and detection until it is rebuilt. As the multi-month baseline lives on storage we manage, we will need to keep backups in the case of accidental deletion, `terraform destroy`, index corruption, or issues with ES upgrades.

We will have full visibility on every stage of the pipeline and we will be able to validate ES|QL against live data.

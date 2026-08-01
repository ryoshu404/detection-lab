# ADR-008: Telemetry Retention and Snapshot Backup

- Date: 2026-07-31
- Deciders: R. Santos
- Related: ADR-002 (SIEM hosting), ADR-004 (ingestion via Agent)

## Status

Accepted

## Context

Four telemetry sources now feed the SIEM, and until now nothing aged out and nothing was backed up. Fleet-managed data streams inherit Elasticsearch's `logs@lifecycle` policy, which ships with a hot phase only: indices roll over, but no delete phase exists, so data accumulates until the disk fills.

The Sysmon config is `olafhartong/sysmon-modular`, chosen deliberately for breadth: events filtered at the sensor cannot be recovered downstream, and a lab that exists to write and tune detections wants visibility rather than economy. That choice is only defensible if retention is managed somewhere.

Separately, the lab had no backup at all. Telemetry regenerates, but the accumulated baseline that FP tuning depends on does not, and neither does the cluster configuration — Fleet policies, integration settings, detection rules, Kibana objects.

### Decision Drivers

- Retention long enough to write a detection and then judge it against a meaningful baseline.
- Snapshot durability that survives loss of the host, not just corruption of an index.
- Cost proportionate to a lab: the AWS side runs at $15-25/month and backup should be noise against that.

### Considered Options

- **Warm and cold ILM phases** — rejected: these move data to cheaper hardware in multi-node clusters. One node, one disk, so they add complexity for nothing. Searchable snapshots and the frozen tier are paid features regardless.
- **Local snapshots** — cheaper and simpler, but protects only against index corruption, not against losing the host. Rejected.
- **Glacier Instant Retrieval for snapshots** — cheaper per GB, but adds retrieval cost and latency to segments Elasticsearch needs to read and delete. A backup that is slow to restore is a worse backup. Rejected.

## Decision

**Retention.** The `logs@lifecycle` policy gains a delete phase at 90 days, and rollover tightens from 50 GB to 30 GB primary shard size. All sixteen data streams inherit it. Note that `min_age` counts from rollover rather than index creation, so data can live up to about 120 days in practice.

Ninety days is chosen to cover the full loop: author a detection, run it in burn-in, and look back across enough baseline to judge false positives.

**Backup.** Snapshots go to S3 (`elastic-snapshots-lab-<account>`) via a repository registered as `s3_lab_backup`. S3 repository support is bundled in Elasticsearch 8.0+, so no plugin is needed. Elasticsearch runs off-AWS on Proxmox with no instance role, so it authenticates with static keys held in the Elasticsearch keystore — the same pattern as `filebeat-local`.

An SLM policy takes a nightly snapshot with `include_global_state: true`, retaining 30 days with a floor of 5 snapshots. Global state matters: it captures Fleet policies, agents, enrollment keys, security config, and Kibana objects, so a restore rebuilds the platform rather than just the data.

The snapshot bucket is excluded from two things the log buckets get. **Versioning** is off, because Elasticsearch deletes segments as snapshots expire and versioning would silently retain them. **The Glacier IR lifecycle** is replaced with a flat 180-day expiry, acting only as a backstop for segments orphaned by a failed delete — SLM handles real retention.

## Consequences

The first full snapshot was 2 GB and took 66 seconds; the next was 14 seconds, confirming incremental behaviour. At that size S3 costs well under a dollar a month, which is noise against the existing AWS spend.

Two things worth knowing. **`logs@lifecycle` is x-pack-managed**, so a stack upgrade may reset it — worth re-checking the delete phase after any upgrade. And **host metrics dominate the data volume**: `metrics-system.process` at 522 MB and `metrics-system.diskio` at 476 MB against Sysmon's 20 MB. Over half of what is retained and backed up is CPU and disk-IO samples with no detection value, collected by the System integration's defaults. That is accepted for now rather than tuned, but it means retention budget is mostly being spent on the wrong data, and disabling metrics collection on the agent policies is the obvious lever if space becomes tight.

Nothing will actually be deleted until roughly November, since the oldest indices rolled over in July. The policy is protective rather than immediately active.

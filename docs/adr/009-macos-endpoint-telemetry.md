# ADR-009: macOS Endpoint Telemetry

- Date: 2026-07-31
- Deciders: R. Santos
- Related: ADR-004 (ingestion via Agent)

## Status

Accepted

## Context

The lab collects endpoint telemetry from Linux via auditd and from Windows via Sysmon. macOS has no equivalent to either: there is no audit subsystem the Agent can manage, and no Sysmon.

The System integration nominally covers macOS, but its syslog input reads `/var/log/system.log`, which on current macOS is nearly empty — Apple moved system logging to the Unified Log years ago. In practice the integration produced four `utmpx` terminal-session entries over several minutes on an active host. That is not thin telemetry; it is effectively none.

Three sources are available instead. **Elastic Defend** uses Apple's Endpoint Security framework, the kernel-level API commercial macOS EDR is built on. **macOS Security Events** applies pre-written NSPredicate filters to the Unified Log across seven curated streams. **Custom macOS Unified Logs** is the same log with predicates left to the operator, and is marked beta.

### Decision Drivers

- Process, file, and network events with enough structure to write precise rules against.
- Coverage of the macOS-specific behaviours this lab cares about — persistence via LaunchAgents and login items, TCC changes, account management — which overlap the domain of the macollect project.
- Telemetry that does not depend on the monitored process choosing to log.

### Considered Options

- **System integration alone** — rejected: reads a log file macOS no longer meaningfully writes to.
- **macOS Security Events alone, all seven streams** — rejected. Unified Log is applications logging about themselves, so a process that logs nothing does not appear, and an attacker can avoid writing to it far more easily than avoiding a syscall. Its entries are also largely free text parsed into `unified_log.*` fields, which is weaker to write rules against than structured process lineage.
- **Elastic Defend alone** — rejected: ESF does not surface launchd activity, TCC decisions, or account management, which is where several macOS-specific detections would key.
- **Both, with overlap removed** — chosen.

## Decision

**Elastic Defend at the Complete EDR tier** is the primary source, providing process, file, and network events from the Endpoint Security framework. Events carry structured `process.executable`, `process.args`, parent lineage, and user context — the macOS analogue of what Sysmon provides on Windows. Collection is available on Basic; the paid gates are on prevention features (ransomware, memory threat, response actions), which are not the point here.

**macOS Security Events** supplements it with three streams that ESF does not cover: Authentication, System Changes, and User and Account Management. The remaining four — Process Execution Monitoring, File Read/Write, Network Activity, Advanced Monitoring — are disabled, because they restate what Defend already reports at lower fidelity and higher volume.

The endpoint runs as a Parallels VM on the Mac mini. Defend requires a system extension approval and Full Disk Access granted through System Settings, since there is no MDM profile to deliver them; both need re-verifying after reboots, as macOS can require re-approval.

## Consequences

macOS telemetry is now comparable in richness to the Windows endpoint, and covers the persistence and permission-change behaviours that macOS detections target. Having two sources is deliberate rather than redundant: kernel-authoritative events for what happened, Unified Log for subsystem decisions ESF cannot see.

Two caveats. This is the only endpoint not declared in Terraform — Parallels has no provider worth depending on, so the VM is hand-built and documented in the node runbook instead. And the local account is `macosuser` rather than the `labadmin` used elsewhere, so rules filtering on `user.name` need to account for both.

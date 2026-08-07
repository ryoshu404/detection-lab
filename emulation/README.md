# Emulation

Attack emulation for the lab. Stratus Red Team detonates cloud-native AWS techniques; Atomic Red Team detonates endpoint techniques. Installation and per-platform gotchas are in `docs/lab-host-setup.md`; the choice of these tools over a hand-rolled harness is in `research-mapping.md`.

This directory holds the record of what was detonated, not the tools themselves.

## Detonation records

Each detonation is one YAML file under `detonations/`, named `<technique-id>_<utc-date>.yml`. One file per detonation rather than a shared append log: fixtures and tests reference a single detonation, a per-file record diffs cleanly and sits beside the fixture it produced, and CI committing to a shared log would generate conflicts.

The record exists to make a detonation recoverable from telemetry later. When a rule is written for a technique, its test needs to find the events that technique produced — which means knowing exactly when it ran, on which host, as which principal, and what it created. The detonation timestamp is the ground-truth label: it is the difference between "the rule fired" and "the rule fired on the event I know I caused."

### Format

```yaml
technique: T1082-1                      # ART test number, or Stratus technique ID
attack_id: T1082                        # MITRE ATT&CK technique
name: System Information Discovery
tool: atomic                            # atomic | stratus
platform: windows                       # windows | linux | macos | aws
host: win-endpoint                      # executing host
principal: Administrator                # executing user / IAM identity
start: 2026-08-01T23:45:08Z             # UTC, from the detonation, not the shell
end: 2026-08-01T23:45:09Z
telemetry:                              # where the events are expected to land
  - logs-windows.sysmon_operational
artifacts:                              # named resources the technique created
  - none
notes: >
  Ran cmd.exe /c systeminfo & reg query ...\Disk\Enum, parented to powershell.
  whoami calls in the same window are ART prereq/elevation checks, not the technique.
```

`start`/`end` are UTC. `Get-Date -AsUTC` is PowerShell 7 only; on Windows PowerShell 5.1 use `(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")`, or take the window from the event timestamps in Elastic after the fact — the indexed events are the authoritative record either way.

`artifacts` matters for Stratus, where warm-up creates named infrastructure. A `cloudtrail-stop` detonation records the throwaway trail name (`stratus-red-team-ct-stop-trail-<rand>`) so the events it generated can be found and so cleanup is verifiable. For most ART tests it is `none`.

`notes` is where framework noise gets flagged — prereq checks, helper processes, anything in the detonation window that is not the technique. This is what the fixture-capture step reviews when deciding which events are the true positives.

### Recorded detonations

The three smoke-test detonations that proved each endpoint's collection path end to end:

| Technique | Host | Telemetry | UTC |
|---|---|---|---|
| T1082-1 | win-endpoint | Sysmon | 2026-08-01T23:45:08Z |
| T1082-3 | linux-endpoint | auditd (execve, full args) | 2026-08-03T02:07:07Z |
| T1082-33 | macos-endpoint | Elastic Defend (ESF) | 2026-08-03T02:32:27Z |

These are proof-of-pipeline, not detection targets. They confirm that a technique executed on each endpoint reaches Elastic on the expected telemetry source. Real technique selection — choosing what to detonate for detection authoring, against what each source actually captures — is tracked separately.

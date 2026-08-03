# Detections

Sigma rules and their strategy docs, organized by ATT&CK tactic, then by telemetry source.

## Layout

```
detections/<tactic>/<source>/<detection-name>/
    rule.yml        # Sigma, metadata inline
    ads.md          # strategy doc (ADS-derived)
    rule.eql        # native EQL, only for documented sequence exceptions (replaces rule.yml)
```

`<tactic>` is the ATT&CK tactic in kebab-case (`credential-access`, `execution`, `exfiltration`, `defense-evasion`, `command-and-control`). Coverage is legible from the tree — this is the primary reason for tactic-first over source-first.

`<source>` is the telemetry source, not the OS — they usually coincide but not always. `network` is Zeek regardless of host OS; `aws` is CloudTrail regardless of anything. Current sources: `windows` (Sysmon + Windows channels), `linux` (auditd), `macos` (Elastic Defend ESF), `aws` (CloudTrail), `network` (Zeek).

Every rule lives at `<tactic>/<source>/<name>/`. No flattening, even when a tactic has only one source — consistency means tooling never has to special-case a directory that collapsed.

`<detection-name>` is one directory per detection, kebab-case, describing the behaviour (`lsass-access`, not `T1003.001`). The technique ID lives in the rule's metadata, not the directory name.

## Rule file

`rule.yml` is Sigma with the metadata block inline (not a sidecar). Required metadata, all consumed downstream:

- `title`, `id` (UUID), `status`, `description`, `author`, `date`
- `tags` — ATT&CK tactic and technique (`attack.credential_access`, `attack.t1003.001`)
- `level` — severity
- `alerting` — burn-in state; `false` until promoted (see below)
- `logsource` — resolved to a data stream by the pipeline

Correlation rules (Sigma v2) reference base rules by id/name and have no `logsource`/`detection` of their own — metadata validation is rule-type aware and must not fail them for absent fields.

## Native EQL exception

Sigma is the source format. Native EQL is permitted only for ordered-sequence detections that Sigma correlation cannot express without fidelity loss — the pySigma Elasticsearch backend buckets correlation events on clock-aligned intervals rather than a true sliding window, which produces false negatives on boundary-straddling events. When taken, the exception is `rule.eql` in place of `rule.yml`, and the reason is recorded in that detection's `ads.md`. It is a documented relaxation of non-negotiable #1, not drift.

## Strategy doc

Every detection has `ads.md`: goal, telemetry assumptions, expected false positives, rejected alternatives, blind spots, and validation method. The validation-method section names the detonation record the rule is tested against, anchoring the doc to a reproducible attack rather than an assertion.

## Burn-in

New rules deploy with `alerting: false` — active and generating detections, but non-paging — for 7-14 days. A follow-up PR flips `alerting: true` to promote. Because the SOAR path is a poller that ships everything to Tines, the `alerting` field is carried as a rule tag that Tines branches on; a burn-in rule's alerts are logged and closed, a promoted rule's create a case.

## Related trees

- `emulation/detonations/` — the ground-truth record for each detonation. A rule's `attack_id` links to a detonation record carrying the same technique, its UTC window, and the artifacts it produced.
- `tests/fixtures/<detonation-id>/` — captured events, their index mappings, and labels, keyed by detonation (not by rule) so sibling rules can test against one capture. CI loads these into a pinned Elastic container, compiles the rule through the lab pipeline, and asserts set-equality against the labels.
- `pipelines/lab-ecs.yml` — the custom pySigma pipeline mapping the `logsource` taxonomy onto the lab's data streams.
- `translations/<tactic>/<source>/<name>.<lang>` — CI-generated compiled output, mirroring the detection path. Never hand-edited.

## Testing tiers

Two tiers, only one of which lives in this repo. The CI tier — deterministic, reproducible by anyone, set-equality against a pinned Elastic service container — is the committed artifact and gates the merge. Live validation against the lab SIEM, where burn-in and false-positive tuning happen, is operational: it leaves no files here, only burn-in promotion PRs and screenshots. `tests/` therefore means exactly one thing, CI fixtures.

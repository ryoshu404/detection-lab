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

New rules deploy with `alerting: false` — active and generating detections, but non-paging — before promotion. This is sometimes called shadow mode. A follow-up PR flips `alerting: true`.

Because the SOAR path is a poller that ships everything to Tines, the `alerting` field is carried as a rule tag that Tines branches on: a burn-in rule's alerts are logged and closed, a promoted rule's create a case.

### Duration

Minimum 3 days, extending to 7 where the telemetry source is new or its stability is unproven.

The production standard is 7–14 days, and the reason is calendar periodicity: many real false positives are weekly-shaped — patch cycles, backup jobs, business-hours login patterns — and a shorter window cannot observe them. That periodicity does not exist here. GHOSTS generates activity continuously with no weekday/weekend rhythm, so a longer window against this baseline observes no additional failure modes.

The condensed window is a deliberate lab tradeoff: building experience across every stage of the lifecycle is worth more than mimicking production duration against a baseline that cannot produce the signal the duration exists to catch. Rules on newly added telemetry take the longer window, since instability and quirks in a fresh source are exactly what a short burn-in would miss.

### Promotion criteria

Both must hold before a rule is promoted.

**1. False-positive profile is understood.** Either the rule's FP volume is low, or the remaining FPs are predictable and sortable in the SOAR layer. Some FP sources cannot be eliminated in the rule without losing true positives; pushing those to Tines enrichment is correct rather than mangling the detection logic to chase them.

The FPs observed during burn-in must match the sources the ADS doc predicted. A rule that is quiet for reasons the doc did not anticipate is not understood — it got a favourable baseline. Where observed and predicted diverge, the ADS doc is updated before promotion.

**2. Detonation generality is confirmed.** The rule fires on a second, independent detonation of the same technique — a hand-rolled variant, or a different atomic exercising the same behaviour through a different tool or code path. Atomics are fixed command lines, and a rule tested only against one can be matching that invocation rather than the technique. This criterion is what catches that.

For cloud rules, an alternative Stratus technique serves this purpose where one exists. Where none does, the criterion is **waived and the waiver noted in the ADS doc**: hand-rolled cloud detonations against a live account lack the isolation and rollback that make endpoint variants safe. Stratus provisions and destroys each technique's own prerequisite infrastructure, keeping detonations isolated from lab-critical resources — a hand-rolled equivalent risks touching real state with no snapshot to roll back to. This is a blast-radius decision, not a capability gap; the API calls themselves are trivial.

## Detonation policy

Two tiers, serving different purposes.

**Primary** — Stratus Red Team (cloud) or Atomic Red Team (endpoints). Reproducible, recorded in `emulation/detonations/`, and captured as the CI fixture. This is the deterministic path that gates merges.

**Secondary** — a hand-rolled variant or alternative atomic, run live against the lab during burn-in to satisfy promotion criterion 2. Not committed as a fixture; noted in the ADS doc. Keeping it out of CI preserves determinism while still testing that the rule generalizes.

Snapshot the endpoint before hand-rolled detonations. Custom attacks can leave residue that an atomic's `-Cleanup` would have handled, and the VM snapshot is the undo.

## Related trees

- `emulation/detonations/` — the ground-truth record for each detonation. A rule's `attack_id` links to a detonation record carrying the same technique, its UTC window, and the artifacts it produced.
- `tests/fixtures/<detonation-id>/` — captured events, their index mappings, and labels, keyed by detonation (not by rule) so sibling rules can test against one capture. CI loads these into a pinned Elastic container, compiles the rule through the lab pipeline, and asserts set-equality against the labels.
- `pipelines/lab-ecs.yml` — the custom pySigma pipeline mapping the `logsource` taxonomy onto the lab's data streams.
- `translations/<tactic>/<source>/<name>.<lang>` — CI-generated compiled output, mirroring the detection path. Never hand-edited.

## Testing tiers

Two tiers, only one of which lives in this repo. The CI tier — deterministic, reproducible by anyone, set-equality against a pinned Elastic service container — is the committed artifact and gates the merge. Live validation against the lab SIEM, where burn-in and false-positive tuning happen, is operational: it leaves no files here, only burn-in promotion PRs and screenshots. `tests/` therefore means exactly one thing, CI fixtures.

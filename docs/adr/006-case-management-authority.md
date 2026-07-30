# ADR-006: SOAR as the System of Record for Case State

- Date: 2026-07-25
- Deciders: R. Santos
- Related: ADR-003 (SOAR platform)

## Status

Accepted

## Context

Detection alerts fire in Elastic and are pushed to Tines by the alert poller. Once an analyst works a case to closure, something has to hold the authoritative answer to "is this resolved?" — and both systems can plausibly claim it.

Elastic's Detection Engine tracks `kibana.alert.workflow_status` per alert, so the SIEM *can* represent case state. Tines has native case management, so the SOAR can too. Leaving it implicit means the two drift and neither is trustworthy.

### Decision Drivers

- One authoritative answer for case state, not two that can disagree.
- Avoid building infrastructure that isn't needed.
- Match how detection and response tooling actually divide responsibility.

### Considered Options

- **Bidirectional sync** — closing in Tines writes back to Elastic so both agree. Rejected: it requires an inbound path to the SIEM (a Cloudflare Access-gated endpoint), introduces two-way consistency to maintain, and implies the SIEM is a case tracker, which muddies the split between detection and response.
- **SOAR as system of record** — chosen.

## Decision

Tines is authoritative for case lifecycle. Elastic alerts are detection triggers, not case records. Analysts investigate and close in Tines; nothing writes back to the SIEM.

This follows the separation these tools are built for: the SIEM detects, the SOAR manages the response lifecycle. Case status in Kibana is not maintained and should not be read as meaningful.

Two things follow directly. The poller stays **one-directional** — Elastic to Tines, no inbound path — which removes the need for the Access-gated write-back endpoint that was previously scoped. And the poller pushes the **full alert payload** rather than a trimmed set of fields, including the rule's triage guidance, so the analyst's runbook travels with the alert into the workspace where the case is actually worked.

## Consequences

`kibana.alert.workflow_status` stays `open` indefinitely on closed cases. That is expected: the Kibana alerts view is a detection-firing record, not a queue, and shouldn't be used as an operational dashboard — Tines is. The lab keeps no inbound network path to the SIEM, which is a security benefit beyond the simplification.

If a reason later emerges to reflect closure in Elastic — a stakeholder watching the Kibana view, or demonstrating bidirectional sync as a capability — the write-back path can be added without reversing anything here. It would be an addition to a working one-directional design, not a correction.

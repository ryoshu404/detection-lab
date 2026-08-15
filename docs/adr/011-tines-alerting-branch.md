# ADR-011: Tines Branches on the Alerting Tag

- Date: 2026-08-09
- Deciders: R. Santos
- Related: ADR-006 (SOAR as system of record), ADR-003 (SOAR platform)

## Status

Accepted

## Context

Rules deploy in burn-in (`alerting: false`) before promotion (`alerting: true`). Both states fire and generate alerts; the difference is what response they warrant. A burn-in alert is data for false-positive analysis and should not page or open a case. A promoted alert should. Something has to act on that distinction, and the poller forwards every alert regardless (ADR-006), so the split has to live downstream.

The `alerting` state is already carried into each alert: the deploy pipeline stamps it as a rule tag, and it rides through to `kibana.alert.rule.tags` on every signal the rule produces.

### Decision Drivers

- The burn-in vs promoted distinction has to produce different response behaviour, or burn-in is meaningless.
- Keep the poller a dumb one-directional forwarder (ADR-006); do not push branching logic into it.
- Match the split these tools are built for: the pipeline decides state, the SOAR acts on it.

### Considered Options

- **Branch in the poller** — inspect the tag and only forward promoted alerts. Rejected: it makes the poller stateful about detection policy, and it drops burn-in alerts entirely, which are the data burn-in exists to collect. The poller should transport, not decide.
- **Two Elastic rule instances per detection** — a paging and a non-paging copy. Rejected: doubles the rule inventory and breaks the single-`rule_id` lifecycle the pipeline relies on.
- **Branch in Tines on the tag** — chosen.

## Decision

Tines reads `kibana.alert.rule.tags` and branches on the `alerting` value. A promoted alert (`alerting:true`) opens a case; a burn-in alert (`alerting:false`) is logged and closed without one. The poller stays unchanged — it forwards everything, and Tines owns the decision.

Tines Community Edition has no native Cases feature, so case creation is proxied by an email action: the promoted branch sends a case-styled notification, the burn-in branch a lower-key logged notification. In an enterprise deployment this branch would open a case in the case-management system; the branching logic is identical regardless of the terminal action.

## Consequences

The `alerting` tag is now load-bearing end to end: the pipeline stamps it, the alert carries it, and Tines acts on it. A rule that reaches Tines without the tag falls through both branches and produces no response — acceptable, since the pipeline requires an explicit `alerting` field on every rule, so an untagged alert would signal a prebuilt or unmanaged rule that this story is not meant to handle.

Promotion is now a response-visible event, not just a metadata change: flipping `alerting` to `true` and redeploying changes what a firing does, which is the point. The email proxy is a lab stand-in and is named as such; replacing it with a real case action is an action swap, not a redesign.

# ADR-003: SOAR Platform Selection

- Date: 2026-07-11
- Deciders: R. Santos

## Status

Accepted

## Context

The lab needs a SOAR layer to demonstrate the alert lifecycle beyond "a rule fires" — enrichment, severity-based routing, and automated resolution. The SIEM is self-hosted Elastic on a local Proxmox VM (ADR-002), so any cloud SOAR must be able to reach a private network, and any self-hosted SOAR must fit the same modest hardware.

### Decision Drivers

- Workflows as code: playbooks should be exportable and version-controllable, consistent with the lab's git-canonical approach.
- Free (or low cost) to operate at the lab's scale.
- Connectivity to a SIEM on a private network.

### Considered Options

- Tines Community Edition (cloud) — chosen
- Tracecat (self-hosted, open-source) — deferred fallback
- Shuffle (self-hosted, open-source) — not selected

## Decision

Tines Community Edition is the SOAR layer. Stories export as version-controllable JSON, the free tier is genuinely usable (25,000 events/month; 3 flows, which matches the three planned playbooks: enrichment, routing, auto-close), and as a hosted platform it adds zero operational load to the lab.

The Tines Tunnel, which is the native way for cloud Tines to reach a private network, is a paid enterprise feature. Connectivity is instead solved by architecture: alerts are **pushed outbound** from the Elastic VM to a Tines webhook by a small poller script, so no inbound access to the network is required, and enrichment runs against public APIs. The one flow that must write back into Elastic (auto-close) reaches it through the lab's existing Cloudflare tunnel, gated with a Cloudflare Access service token.

Tracecat is the deferred fallback: self-hosted, no flow or retention limits, and a similar workflow paradigm, so playbook logic ports over if Tines CE's limits become binding. Shuffle covers similar ground but with less alignment to the workflows-as-code approach.

## Consequences

The lab gets a SOAR with workflows in git at zero cost and near-zero operational overhead. The push-plus-Access-token connectivity is more engineering than a vendor add-on would be, but it keeps the network fully closed to inbound traffic and documents a reusable pattern for integrating any cloud service with a private SIEM.

The constraints are real: the 3-flow cap exactly fits the three planned playbooks with no headroom, and CE's short event retention makes long-lived automation state impractical — both are reasons Tracecat is pre-positioned as the fallback rather than an afterthought. The alert-push path adds a small script on the Elastic VM that can fail silently; a scheduled dead-man's-switch flow (alert if no events received in 24h) covers that failure mode.

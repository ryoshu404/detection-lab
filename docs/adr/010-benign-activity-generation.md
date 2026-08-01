# ADR-010: Benign Activity Generation

- Date: 2026-08-01
- Deciders: R. Santos

## Status

Accepted

## Context

The endpoints were silent. Apart from agent heartbeats and the operator's own SSH sessions, nothing happened on them. A detection tested against that environment separates one attack from nothing at all, which says nothing about how it behaves against real traffic — and false-positive rates measured against silence are meaningless.

Baseline noise also cannot be generated retroactively. Telemetry only exists for periods when something was running, so the decision had to be made before detection authoring rather than alongside it.

### Decision Drivers

- Enough plausible activity that a detection has to distinguish an attack from legitimate behaviour, not from an empty machine.
- Activity that is distinguishable from the operator's own administrative work when reading telemetry later.
- Effort proportionate to a lab with three endpoints.

### Considered Options

- **A hand-written script per endpoint** — cheap, fully controlled, but it reproduces whatever the author imagines a user does. Rejected as the primary approach: the patterns would be narrow and obviously synthetic, and it is reinventing something that exists.
- **Using the endpoints manually** — real activity, but sporadic and not reproducible.
- **GHOSTS** — chosen. Purpose-built for this, maintained by CMU/SEI, and generates activity from configurable timelines rather than fixed scripts.

## Decision

GHOSTS runs as the benign activity generator. The API stack (five containers: API, frontend, Postgres, n8n, Grafana) runs on a dedicated VM on pve2 rather than an LXC, because Docker inside an unprivileged container requires the nesting feature flag, which the Proxmox API token cannot reliably set.

Clients are chosen per endpoint. The **Universal** client runs on Linux — the documented default there, requiring .NET 9 or later. The **Windows** client runs on Windows: it needs only .NET Framework 4.6.1, which ships with the OS, and is the mature client for that platform. **macOS is unresolved** — the documentation lists macOS support for the Universal client, but the v9.0.0 release ships no darwin build. A lightweight script is the likely fallback there.

**Each endpoint runs GHOSTS under its own service account** — `jsmith` on Linux, `spoli` on Windows — rather than the administrative account used to manage the machine. This is the part that matters for detection work: without it, simulated activity and the operator's own commands are indistinguishable in telemetry, and every subsequent question about whether a given event was noise or investigation requires manual inspection. With separate accounts, `user.name` answers it.

On Windows this forces auto-login for the service account, because the GUI handlers need an interactive session. That weakens the endpoint's security posture deliberately — anyone reaching that console lands in a logged-in session — which is acceptable for a lab endpoint whose purpose is generating observable activity.

## Consequences

The endpoints now produce continuous workstation- and server-shaped telemetry, so detections can be tuned against something. Simulated activity is attributable by user account, which makes false-positive analysis tractable rather than archaeological.

Costs and caveats. Volume increases across every source — the retention policy in ADR-008 now has something substantial to hold. The default timelines are generic and partly wrong for this environment: the Linux one repeatedly attempts SSH to a host that does not exist, which generates a fixed and rather unconvincing pattern. Per-OS timelines matching each machine's role are outstanding work: server-shaped activity for Linux, workstation-shaped including browsing for Windows and macOS.

The GHOSTS API stack itself is not monitored. It is lab tooling rather than a detection target, and its own container activity would be noise.

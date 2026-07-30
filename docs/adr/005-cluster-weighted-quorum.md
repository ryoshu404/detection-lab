# ADR-005: Two-Node Proxmox Cluster with Weighted Quorum

- Date: 2026-07-25
- Deciders: R. Santos
- Supersedes: the original standalone-nodes plan, which assumed the second host would be an isolated malware-analysis box.

## Status

Accepted

## Context

A second Proxmox host (`pve2`) was added to take endpoint workloads off the lab host, which was approaching its RAM ceiling with the SIEM stack plus a Linux endpoint.

The remaining question is quorum. A two-node cluster has no tiebreaker: with one vote each, either node failing leaves the survivor at 1 of 2, below majority, and `/etc/pve` goes read-only.

### Decision Drivers

- One Terraform stack. A cluster shares an API endpoint, so `terraform/onprem/` targets either host via `node_name`. Standalone nodes would need a second provider alias (with its own token) or a second stack and state file.
- One management pane. Both nodes and all guests visible from a single login, which matters because all access is through Guacamole.
- Quorum must not require hardware that doesn't exist.

### Considered Options

- **Standalone nodes** — no quorum concerns, but fragments the Terraform and doubles the management surface. Rejected: the IaC cost outweighs the simplicity.
- **Cluster + QDevice** — a third voter (`corosync-qnetd`) gives symmetric resilience: either node survives alone. Rejected: it must run on hardware separate from both nodes, and nothing suitable is on hand. The Windows and Mac minis could only host it inside a Linux VM, which makes the tiebreaker depend on a VM staying up — fragile for its purpose. A dedicated Pi would work but wasn't worth buying for this.
- **Cluster + weighted votes** — chosen. No third device, and the asymmetry it forces happens to match the asymmetry that already exists.

## Decision

Both hosts run Proxmox VE 9.2.5 in a cluster named `detection-lab`. `pve` (192.168.1.10) is assigned **2 votes**, `pve2` (192.168.1.30) **1**, for 3 expected votes with a quorum of 2.

The asymmetry is deliberate and follows criticality. `pve` runs Elasticsearch, Kibana, Fleet Server, Guacamole, and the Linux endpoint; `pve2` hosts endpoints only. If `pve2` fails, `pve` holds 2 of 3 votes and keeps running. If `pve` fails, `pve2` drops to 1 of 3 and goes read-only — which costs little, because losing `pve` means the SIEM and the remote-access path are already down and the outage is being worked either way.

Vote weights live in `/etc/pve/corosync.conf`. Changes there require incrementing `config_version` or corosync ignores them; the file and the running state can silently disagree otherwise.

## Consequences

Terraform manages both hosts from the existing `onprem/` stack — new resources target `pve2` with `node_name`, and existing resources are unchanged. Guests can migrate between nodes, though this weakens the IP convention (`.1x` for node 1's guests, `.3x` for node 2's) as a reliable indicator of where something runs.

Costs and caveats: corosync shares the flat gigabit LAN with lab traffic rather than a dedicated link, so heavy transfers or ingestion spikes could cause membership flapping — acceptable at this scale, but the first thing to suspect if the cluster behaves oddly. Resilience is asymmetric by design, not an oversight. Adding a QDevice later would make it symmetric without undoing anything here.

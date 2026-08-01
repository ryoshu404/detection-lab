# ADR-007: Open vSwitch on pve2 for Passive Network Capture

- Date: 2026-07-31
- Deciders: R. Santos
- Related: ADR-005 (two-node cluster)

## Status

Accepted

## Context

The lab collects cloud telemetry (CloudTrail, GuardDuty) and endpoint telemetry (auditd, and Sysmon once Windows exists), but nothing at the network layer. That is the one gap against the SIEM/EDR/NDR/SOAR set that shows up in the roles this lab is built for, and it closes off a whole class of detection — beaconing, DNS tunneling, unusual egress — that host telemetry alone does not support well.

Endpoints are Proxmox guests, so the traffic worth capturing is already crossing a virtual bridge. The obstacle is that a Linux bridge forwards frames only to the destination port and has no mirroring, so a sensor attached to it sees nothing but its own traffic.

### Decision Drivers

- One sensor should cover every endpoint regardless of OS, rather than per-OS agents.
- Capture should survive endpoint compromise — an attacker on the host should not be able to stop it.
- Mirroring configuration should persist across VM restarts without glue scripts.

### Considered Options

- **Host-based capture** (Elastic's Network Packet Capture integration, or Zeek installed on each endpoint) — cheapest, a policy toggle on an agent already deployed. Rejected as the primary answer: it is per-OS, and it runs inside the thing being monitored, so it is tamper-visible to anything that owns the host. Still useful as a supplement.
- **`tc` mirroring on the Linux bridge** — works, but tap interfaces are created and destroyed with the VM, so the rules vanish on every stop. Keeping them requires a Proxmox hookscript per mirrored VM plus separate ingress and egress rules. Rejected: fragility to avoid a one-time change.
- **Open vSwitch with port mirroring** — chosen. Mirroring is a property of the switch config, so it persists without scaffolding.

## Decision

`vmbr0` on **pve2** was converted from a Linux bridge to an OVS bridge, keeping the same name so guest configs referencing it need no changes. Mirroring is configured through `ovs-vsctl` and lives in the OVS database rather than `/etc/network/interfaces`.

The conversion was done while pve2 had no guests. That timing was the point: rewriting the bridge on an empty node risks only the node, where the same change later would mean stopping every endpoint and planning a rollback.

Because mirroring only exists on pve2, **endpoints live on pve2 and the detection platform stays on pve**. That split follows from the sensor rather than the other way round — Elasticsearch, Kibana, Fleet, and Guacamole are not things being detected on, and their traffic would be noise in a capture. The Linux endpoint was migrated off pve accordingly, and its address moved to `192.168.1.31` to reflect its new "physical" location (pve is on .10 and pve2 is on .30 since .20 is reserved in my current network)

## Consequences

Network capture now covers any endpoint on pve2 with one sensor, independent of guest OS, and outside the reach of a compromised host. It also gives pve room: with the endpoint moved off, the SIEM host keeps its headroom for the data growth that sustained operation implies.

The conversion is not free of edge cases. The physical NIC needs `auto` rather than `allow-vmbr0` in `/etc/network/interfaces` or the port is not added to the bridge at boot, which presents as a node with a bridge and no uplink. Physical console access is the recovery path and should be in place before the change, not after.

This is host-level configuration with no Terraform representation, so the reasoning lives here and the procedure lives in `docs/lab-host-setup.md`. Host-based capture stays available and complementary: Sysmon gives Windows network events with process attribution, which a passive sensor cannot provide, and the two answer different questions about the same traffic.

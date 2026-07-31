# Proxmox Node Setup

The hypervisor layer is not managed by Terraform. The bpg provider creates guests through the Proxmox API; it does not install Proxmox, form clusters, or configure host networking. Those are day-zero tasks, done by hand, and this is the record of how — so a node can be rebuilt without reconstructing the choices from memory.

Guests are in `terraform/onprem/`. Decisions behind the cluster and network layout are in ADR-005 and ADR-007.

## Current nodes

| Node | Hardware | Address | Role |
|---|---|---|---|
| `pve` | ThinkCentre M75q Gen2, Ryzen 5 PRO 4650GE, 32 GB | 192.168.1.10 | Detection platform — Elastic, Kibana, Fleet, Guacamole |
| `pve2` | OptiPlex 5090 Micro, i5-10500T, 32 GB | 192.168.1.30 | Detection targets — endpoints, supporting tooling |

Both nodes run Proxmox VE 9.2.5 on Debian 13 (Trixie).

## BIOS

Settings that matter, and the symptom when they're wrong:

- **Virtualization** — Intel VT-x, or AMD-V/SVM on the Ryzen box. Off means no VMs.
- **VT for Direct I/O (VT-d)** — enabled; only needed for device passthrough, but cheaper to set now.
- **SATA Operation → AHCI** — Dell ships OptiPlex machines in RAID (Intel RST) mode, and the Linux installer then shows **no disks at all**. This is the setting that wastes an hour if you don't know about it.
- **Secure Boot → disabled** — Proxmox 9 supports it, but disabling removes a variable.
- **AC Power Recovery → Power On** — an always-on cluster node should come back after an outage without someone pressing a button.
- **TXT → leave disabled.** Unrelated to virtualization, and enabling it can break boot.

Both nodes are on a UPS, which covers short outages; AC Power Recovery covers anything longer.

## Install

Graphical installer, top option, no Advanced options — that yields **ext4 on LVM**, matching both nodes. ZFS was considered, but was rejected to keep RAM available for current and future guests. Proxmox VM snapshots are sufficient.

Set the management IP during install rather than after.

To change the address afterwards, both files need editing, from the console rather than over SSH:

```
/etc/network/interfaces    # vmbr0 stanza
/etc/hosts                 # hostname mapping
```

They must agree. A mismatch breaks `pveproxy` and, later, cluster join.

## Repositories

A fresh install points at the enterprise repo, which 401s without a subscription. Disable it, and Ceph's enterprise repo with it:

```
/etc/apt/sources.list.d/pve-enterprise.sources   Enabled: false
/etc/apt/sources.list.d/ceph.sources             Enabled: false
/etc/apt/sources.list.d/proxmox.sources          pve-no-subscription   (default, leave enabled)
```

The GUI (node → Updates → Repositories) writes the deb822 format correctly; hand-editing is possible but easy to get subtly wrong. Then `apt update && apt dist-upgrade` and reboot.

## Cluster

Create on the first node, join from the second. A joining node must have no guests — the join replaces its `/etc/pve` entirely.

```bash
# on pve
pvecm create detection-lab

# on pve2
pvecm add 192.168.1.10 -fingerprint '<from the prompt>'
```

Passing `-fingerprint` explicitly matters: accepting it at the interactive prompt is not sufficient and the join fails with `500 Can't connect ... hostname verification failed`. The GUI path (Datacenter → Cluster → Join Information, paste on the joining node) embeds the fingerprint and avoids this.

Back up guest configs first. `/etc/pve/qemu-server` and `/etc/pve/lxc` are symlinks into `nodes/<name>/`, so `tar` without `-h` archives the links and nothing else — use `cp -rL` or archive the real paths.

### Weighted quorum

Two nodes means either failing leaves the survivor below majority and `/etc/pve` read-only. With no third device available for a QDevice, `pve` carries two votes:

```
/etc/pve/corosync.conf
  nodelist → node pve → quorum_votes: 2
  totem    → config_version: <increment>
```

**The version bump is not optional.** Corosync ignores changes without it, and the file and running state then disagree silently. Verify with `pvecm status`: expect 3 expected votes, quorum 2, and `pve` showing 2 votes.

Rationale in ADR-005.

## Networking

`pve` runs a standard Linux bridge. `pve2` runs Open vSwitch so endpoint traffic can be mirrored to a sensor (ADR-007).

```
# pve2 /etc/network/interfaces
auto lo
iface lo inet loopback

auto nic0
iface nic0 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr0

auto vmbr0
iface vmbr0 inet static
    address 192.168.1.30/24
    gateway 192.168.1.1
    ovs_type OVSBridge
    ovs_ports nic0

source /etc/network/interfaces.d/*
```

Install `openvswitch-switch` **before** rewriting the file, keep the bridge named `vmbr0` so guest configs still resolve, and back up the working config first. `auto nic0` rather than `allow-vmbr0 nic0` — the latter does not reliably add the port at boot, and the result is a bridge with no uplink and an unreachable node. Have a monitor attached before rebooting; recovery is restoring the backup at the console.

Mirroring is configured with `ovs-vsctl` and persists in the OVS database, not in `/etc/network/interfaces` — so it is **not** covered by backing up that file.

## Storage

`local` is per-node directory storage. It is not shared, and this bites in three places:

- ISOs uploaded to one node are invisible to the other.
- Cloud-init snippets under `local:snippets/` must exist on the node where the VM runs. Migrating a VM without copying its snippet fails at start with `volume ... does not exist`.
- Cloud images referenced by `vm_image_file_id` must exist on the target node, or a rebuild there fails.

Copy files between nodes as needed, or add shared storage (NFS from a NAS) and stop working around it. Note that `local` needs the Snippets content type enabled per node.

VM disks live in the `pve-data` LVM thin pool. `lvs` shows *allocated blocks*, not filesystem usage — a volume reading 95% can be 32% full inside. `fstrim` returns freed blocks, and must run on the host: unprivileged containers cannot issue FITRIM.

## Guest conventions

- **Guest swap is off, host swap is on.** Elasticsearch should not swap; the hypervisor benefits from the cushion.

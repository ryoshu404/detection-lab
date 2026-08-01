# Lab Host Setup

The host layer is not managed by Terraform. The bpg provider creates guests through the Proxmox API; it does not install Proxmox, form clusters, or configure host networking. The Mac mini is outside Terraform entirely — Parallels has no provider worth depending on. Those are day-zero tasks, done by hand, and this is the record of how, so a host can be rebuilt without reconstructing the choices from memory.

Guests on Proxmox are in `terraform/onprem/`. Decisions behind the cluster and network layout are in ADR-005 and ADR-007; macOS telemetry is in ADR-009.

## Hosts

| Host | Hardware | Address | Role |
|---|---|---|---|
| `pve` | ThinkCentre M75q Gen2, Ryzen 5 PRO 4650GE, 32 GB | 192.168.1.10 | Detection platform — Elastic, Kibana, Fleet, Guacamole |
| `pve2` | OptiPlex 5090 Micro, i5-10500T, 32 GB | 192.168.1.30 | Detection targets — endpoints, supporting tooling |
| Mac mini | M4 | — | macOS endpoint, as a Parallels VM |

Both Proxmox nodes run VE 9.2.5 on Debian 13 (Trixie).

---

# Proxmox nodes

## BIOS

Settings that matter, and the symptom when they're wrong:

- **Virtualization** — Intel VT-x, or AMD-V/SVM on the Ryzen box. Off means no VMs.
- **VT for Direct I/O (VT-d)** — enabled; only needed for device passthrough, but cheaper to set now.
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

---

# Mac mini

The macOS endpoint is a Parallels VM rather than the host itself, so attack emulation runs somewhere disposable and snapshots are available for revert cycles. It is the only guest in the lab not declared in Terraform.

## VM creation

Choose **Customize settings before installation** — networking has to be set before first boot.

- **Network: Bridged → Ethernet**, not Default Adapter. Default follows whatever the host is using and shifts if interfaces change; bridged Ethernet is deterministic and puts the VM on the LAN where Fleet can reach it. Shared/NAT does not work.
- **8 GB RAM, 4 cores, 80–100 GB disk.**
- **Startup and shutdown: Custom** — start when the Mac starts, keep running when the window closes. The default "Always Ready in Background" is built for running a single app, not for an endpoint you manage.

Parallels installs the host's macOS version by default; an IPSW can be supplied to install a different one. Apple's licensing permits two macOS VMs per host.

The local account is `macosuser`, not the `labadmin` used on the Linux and Windows endpoints.

## Always-on settings

The VM should stay running and logged in so telemetry is continuous and it is usable unattended.

```bash
# in the VM, and on the Mac mini host — a sleeping host stops the VM
sudo pmset -a sleep 0 displaysleep 0 disksleep 0
pmset -g          # verify
```

Then in System Settings:

- **Lock Screen** — screen saver Never, display off Never, require password Never
- **Users & Groups** — automatic login as `macosuser`

Automatic login is greyed out while FileVault is on. Turn FileVault off; for a disposable lab VM it adds nothing and complicates snapshots.

## Elastic Defend permissions

Defend needs permissions that would normally arrive via an MDM profile. Without one they are granted by hand, and the integration reports unhealthy until they are:

- **Privacy & Security** — an "Allow" prompt appears for the blocked Elastic system extension
- **Privacy & Security → Full Disk Access** — enable `ElasticEndpoint`, adding `/Library/Elastic/Endpoint/elastic-endpoint` manually if it is not listed

A reboot is often needed before the extension loads. Verify:

```bash
sudo systemextensionsctl list      # expect the Elastic extension activated enabled
sudo elastic-agent status --output full
```

macOS can require re-approval after reboots or updates, so this is worth re-checking rather than assuming it persists. Which sources are enabled and why is in ADR-009.

## Snapshots

Take a snapshot once the agent is enrolled, permissions are granted, and the VM has been rebooted to confirm all three survive a restart. A snapshot of a state that only works until it restarts is not a useful revert point.

---

# GHOSTS clients

The server runs on `ghosts` (192.168.1.34), declared in `terraform/onprem/`. Clients are installed by hand on each endpoint and are not in Terraform. Rationale for the tool and the account separation is in ADR-010.

Each endpoint runs GHOSTS under a dedicated service account rather than the administrative one, so simulated activity is distinguishable from operator activity in telemetry.

| Endpoint | Client | Account | Path |
|---|---|---|---|
| linux-endpoint | Universal | `jsmith` | `/home/jsmith/ghosts/publish/linux-x64` |
| win-endpoint | Windows | `spoli` | `C:\exercise\ghosts` |
| macos-endpoint | — | — | unresolved; no darwin build ships in v9.0.0 |

Every client's `config/application.{json,yaml}` needs `ApiRootUrl` set to `http://192.168.1.34:5000/api`. The `/api` suffix is required; without it the client cannot register.

Confirm registration by checking that `instance/id.json` exists on the endpoint, or that the machine appears at `http://192.168.1.34:5000/api/machines` with the expected `currentUsername`.

## Linux

The Universal client needs .NET 9 or later. Ubuntu 22.04's apt repositories stop at 8, so use the snap:

```bash
sudo snap install dotnet --classic
sudo apt install -y libicu-dev
```

The snap installs to `/snap/bin/dotnet`, which the client's native launcher (`./Ghosts.Client.Universal`) does not find — it only searches the standard locations and fails with "You must install .NET to run this application." Invoke the DLL through the snap binary instead. Note the DLL name is capitalised; the documentation's lowercase form does not match on a case-sensitive filesystem.

Do not copy the `instance/` directory between machines or accounts — it holds the registration ID, and a copy will claim the original's identity.

```ini
# /etc/systemd/system/ghosts.service
[Unit]
Description=GHOSTS Client Service
After=network.target

[Service]
ExecStart=/snap/bin/dotnet /home/jsmith/ghosts/publish/linux-x64/Ghosts.Client.Universal.dll
WorkingDirectory=/home/jsmith/ghosts/publish/linux-x64
Restart=always
User=jsmith
Group=jsmith
Environment=DOTNET_CLI_TELEMETRY_OPTOUT=1

[Install]
WantedBy=multi-user.target
```

The documentation's example unit sets `DISPLAY=:0`; that is for GUI handlers and is omitted here, since this is a headless server running Bash, Curl, and SSH handlers only.

## Windows

The Windows client needs .NET Framework 4.6.1, which ships with Windows 11 — no runtime install.

Its GUI handlers require an **interactive session**, so the service account has to be logged in. Auto-login is configured for `spoli`. The `netplwiz` checkbox is hidden while Windows Hello sign-in is enforced, so either disable that in Settings → Accounts → Sign-in options, or set it directly:

```powershell
$k = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty $k AutoAdminLogon "1"
Set-ItemProperty $k DefaultUserName "spoli"
Set-ItemProperty $k DefaultPassword "<password>"
```

This stores the password in plaintext in the registry, readable by any local administrator. It is a deliberate tradeoff for continuous activity on a lab endpoint.

The client is installed under `C:\exercise\ghosts` rather than the service account's profile, so it needs write access for `logs/`, `instance/`, and `config/`:

```powershell
icacls "C:\exercise\ghosts" /grant "spoli:(OI)(CI)M" /T
```

Run `ghosts.exe` from `spoli`'s session, not as administrator — the account that first runs it is the one recorded against the machine.

Elastic Agent and Sysmon are unaffected by any of this. Both run as services under SYSTEM and continue reporting regardless of session state, so losing the auto-login costs the noise but not the monitoring.

---

# Network sensor

Zeek runs on `sensor` (192.168.1.35), declared in `terraform/onprem/`, receiving an OVS port mirror from pve2. Rationale for the passive-sensor approach is in ADR-007.

The VM has two interfaces. `eth0` carries management traffic — SSH, Fleet enrollment, shipping logs. `eth1` receives the mirror and has **no address**, so the sensor has no presence on the segment it monitors and cannot be reached across it.

## Mirror configuration

The mirror is created with `ovs-vsctl` on **pve2** and lives in the OVS database, not in `/etc/network/interfaces` — so backing up that file does not capture it.

Endpoint tap interfaces are the sources; the sensor's second interface is the destination. Confirm the interface names first, since they follow VMID and device index:

```bash
ip -br link | grep tap
```

`tap103i0` is the Linux endpoint, `tap105i0` the Windows endpoint, `tap107i1` the sensor's capture interface. LXC guests use `veth` rather than `tap` and are not mirrored — they are tooling, not detection targets.

```bash
ovs-vsctl -- set bridge vmbr0 mirrors=@m \
  -- --id=@src1 get port tap103i0 \
  -- --id=@src2 get port tap105i0 \
  -- --id=@dst get port tap107i1 \
  -- --id=@m create mirror name=zeek-mirror \
     select-src-port=@src1,@src2 \
     select-dst-port=@src1,@src2 \
     output-port=@dst
```

Listing both endpoints under `select-src-port` and `select-dst-port` captures each conversation in both directions.

Verify with `ovs-vsctl list mirror` — `statistics` shows packet counts, which is the quickest confirmation traffic is flowing. Then check it arrives:

```bash
sudo tcpdump -i eth1 -c 20 -n     # on the sensor
```

Tap interfaces are recreated when a VM restarts. Whether OVS re-binds the mirror to a recreated tap of the same name has not been verified here; if mirroring stops after an endpoint reboot, check `ovs-vsctl list mirror` still shows the ports bound.

## Capture interface

`eth1` must be up but unaddressed. Cloud-init assigns DHCP to unconfigured interfaces by default, so netplan needs an explicit override, and cloud-init's network management has to be disabled or it regenerates the file on reboot:

```bash
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```

```yaml
    eth1:
      dhcp4: false
      dhcp6: false
      optional: true
```

`optional: true` matters — without it boot waits for an interface that will never acquire an address.

Promiscuous mode is set by Zeek itself when it starts capturing, so no separate configuration is needed. Confirm with `ip -d link show eth1 | grep -i promisc`.

## Zeek

Binary packages come from the openSUSE Build Service; the repository path is per-Ubuntu-release, and this host is Jammy.

```bash
echo 'deb http://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/ /' | sudo tee /etc/apt/sources.list.d/security:zeek.list
curl -fsSL https://download.opensuse.org/repositories/security:zeek/xUbuntu_22.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/security_zeek.gpg > /dev/null
sudo apt update
sudo apt install -y zeek-8.0
```

Postfix is pulled in as a dependency for Zeek's notice emails. Choose **No configuration** — notices go to `notice.log` and are shipped to Elasticsearch, so mail is not needed.

Set the capture interface in `/opt/zeek/etc/node.cfg`:

```
[zeek]
type=standalone
host=localhost
interface=eth1
```

And declare the lab network in `/opt/zeek/etc/networks.cfg` so Zeek classifies traffic direction correctly.

### JSON output

Zeek writes TSV by default; the Elastic integration expects JSON. The `json-streaming-logs` package writes JSON alongside the TSV files:

```bash
sudo /opt/zeek/bin/zkg install corelight/json-streaming-logs
```

**Installing is not enough.** `zkg` adds the package to the bundle, but `local.zeek` must load it, and the `@load packages` line ships commented out:

```bash
sudo nano /opt/zeek/share/zeek/site/local.zeek     # uncomment @load packages
sudo /opt/zeek/bin/zeekctl deploy
```

Output appears as `json_streaming_<name>.log`, with rotated copies as `json_streaming_<name>.1.log`. Both formats are written, which doubles log volume — if disk becomes tight, `redef LogAscii::use_json = T;` in `local.zeek` replaces TSV entirely instead.

## Elastic integration

The sensor runs the Zeek integration only. The System integration is removed from its policy: the box's own process and metric telemetry is noise, and its purpose is shipping network observations.

Set **Base Path** to `/opt/zeek/logs/current`, and each enabled log's filename to the `json_streaming_` prefixed name — the defaults assume plain `conn.log` and will match nothing.

Enabled: conn, dns, ssl, notice, weird, x509, known_services, plus http, ssh, smb_mapping, and kerberos in anticipation of Windows and emulation traffic. The industrial protocols and Zeek's own instrumentation logs (stats, telemetry, loaded_scripts) are left off. "Preserve original event" is off throughout — it duplicates each event into `event.original` for data already readable.

# Windows 11 endpoint image

Packer build producing a Proxmox template for the Windows detection endpoint.
Runs on the `builder` container (192.168.1.32), builds on `pve2`.

## What it does

Unattended Windows 11 install with VirtIO drivers injected during setup,
UEFI firmware with Secure Boot and a virtual TPM 2.0 (satisfying Windows 11's
requirements rather than bypassing them), then Sysmon with
[sysmon-modular](https://github.com/olafhartong/sysmon-modular).

Elastic Agent is **not** baked in. Enrollment tokens are per-agent, so
enrollment happens after cloning.

## Prerequisites

On `pve2`, in `local` ISO storage:

- `Win11_25H2_English_x64_v2.iso`
- `virtio-win.iso`

`local` must accept both ISO and Snippets content types. Note that `local`
is per-node — ISOs on `pve` are not visible here.

## Usage

```bash
cp windows11.auto.pkrvars.hcl.example windows11.auto.pkrvars.hcl
# fill in the API token and admin password
packer init .
packer validate .
packer build .
```

The real `.auto.pkrvars.hcl` is gitignored.

## Notes

**Answer file delivery.** Proxmox has no floppy support, so `Autounattend.xml`
is delivered on an ISO that Packer builds from `cd_files`.

**Drive letters.** The answer file assumes the VirtIO ISO is `E:` during
WinPE and the answer-file ISO is `D:` at first logon. WinPE letter assignment
is not guaranteed. If setup fails to find a disk or `enable-winrm.ps1` does
not run, this is the first thing to check.

**Sysprep.** Not run. The template is cloned once, for a single endpoint, so
generalising is unnecessary. Cloning more than one Windows endpoint from this
template would need sysprep added to avoid duplicate SIDs.

**Build time.** Expect 30-60 minutes. `winrm_timeout` is set to 2h to
accommodate a slow install.

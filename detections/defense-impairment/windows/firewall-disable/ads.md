# Disabled System Firewall

- Rule: rule.yml
- Status: Live since 2026-08-15
- Author: ryoshu404
- Date: 2026-08-06

## Goal

This detection aims to alert on threat actors disabling the Windows host firewall. This technique enables threat actors to perform follow-on actions on the system with a weakened network control.

## MITRE categorization

This behavior is categorized as [Defense Impairment / T1686.003 Disable or Modify System Firewall: Windows Host Firewall](https://attack.mitre.org/techniques/T1686/003/).

[DET0145 Detection of Disabled or Modified System Firewalls across OS Platforms](https://attack.mitre.org/detectionstrategies/DET0145/#AN0406) covers possible detection methods for this technique.

## Source format

Sigma

## Detection functionality

The detection will work as follows:
- Utilizing Windows Sysmon Operational Logs:
	- Look for Sysmon EID 13
	- Identify events where the registry path is one of:
		- `...\SharedAccess\Parameters\FirewallPolicy\DomainProfile\EnableFirewall`
		- `...\SharedAccess\Parameters\FirewallPolicy\StandardProfile\EnableFirewall`
		- `...\SharedAccess\Parameters\FirewallPolicy\PublicProfile\EnableFirewall`
	- Identify events where the registry value for the above paths is `0`
	- Fire alert if above conditions are met

## Blind spots and assumptions

This detection relies on Sysmon being enabled and the configuration in use logging EID 13.

It was decided to filter only on the registry value being `0`, so a possible blind spot is missing the clean-up of this activity, which would set the value back to `1`, but it was decided to scope on `0` only since restoring the firewall isn't the attack or the technique itself. Detections for an attacker disabling logging beforehand, the case that would blind this rule entirely, are covered separately by planned defense-impairment detections (Sysmon driver unload, ETW provider disable), not yet authored.

The registry write is attributed to different processes depending on method: `svchost.exe` when driven through the firewall service (e.g. netsh), and `reg.exe` when the key is written directly. The actor is therefore not reliable from this event alone, so the rule keys on the state change rather than the process.

## False positives

The lab baseline cannot produce meaningful FP data because the current GHOSTS configuration doesn't touch firewall state. In an enterprise environment possible use cases would be:
- Turning off the firewall during network troubleshooting
- A third-party solution managing firewall state
- Group Policy pushing a firewall-disabled state, which surfaces as `svchost.exe` and is indistinguishable from netsh at the registry event

However, in most scenarios such environments would utilize Windows exclusions instead of turning off the firewall altogether, so a full disable is inherently high-signal.

## Validation

This detection was validated using Atomic Red Team.

- Primary: `T1686-1 Disable Microsoft Defender Firewall` (netsh) detonation [`emulation\detonations\T1686.003-1_2026-08-06.yml`](../../../../emulation/detonations/T1686.003-1_2026-08-06.yml), captured as the CI fixture [`tests\fixtures\T1686.003_2026-08-06`](../../../../tests/fixtures/T1686.003_2026-08-06).
- Secondary: `T1686-2 Disable Microsoft Defender Firewall via Registry` (reg add) detonation [`emulation\detonations\T1686.003-2_2026-08-06.yml`]((../../../../emulation/detonations/T1686.003-2_2026-08-06.yml)), captured in the same fixture [`tests\fixtures\T1686.003_2026-08-06`](../../../../tests/fixtures/T1686.003_2026-08-06).

The detection alerted on both, and the registry write was attributed to a different process in each (`svchost.exe` for netsh, `reg.exe` for the direct registry write), confirming the rule keys on the state change rather than the method.

The rule was promoted to `alerting: true` on 2026-08-15 and confirmed firing live against a fresh detonation [`emulation/detonations/T1686.003-1_2026-08-15.yml`](../../../../emulation/detonations/T1686.003-1_2026-08-15.yml), routing through the poller to the Tines promoted branch and producing a case notification rather than a burn-in log.

## Initial query (ES|QL)

This is the base query in ES|QL used to spot this technique. For the detection itself we added a filter for the value being `0`, since that equates to the firewall being disabled.

```
FROM logs-windows.sysmon_operational-*
| WHERE event.code == "13"
    AND registry.path LIKE "*FirewallPolicy*EnableFirewall*"
| KEEP @timestamp, registry.path, registry.data.strings, process.name, process.parent.name
| SORT @timestamp ASC
```

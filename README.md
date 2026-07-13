# detection-lab

A detection engineering lab spanning cloud and endpoint telemetry, feeding a self-hosted Elastic SIEM. AWS provides the cloud signal (CloudTrail, GuardDuty, and VPC Flow Logs) while Windows, Linux, and macOS endpoints provide host signal. Detection rules are authored in Sigma and compiled to Elastic via [pySigma](https://github.com/SigmaHQ/pySigma), keeping the source format SIEM-portable.

The workflow follows the Detection-as-Code patterns in Lussier's [Implementing a Modern Detection Engineering Workflow](https://security.googlecloudcommunity.com/community-blog-42/implementing-a-modern-detection-engineering-workflow-part-1-4054), adapted to a Sigma + AWS + Elastic toolchain.

## Architecture

- **Cloud telemetry:** Terraform-managed AWS — CloudTrail (multi-region, log validation), GuardDuty, VPC Flow Logs, S3 log buckets with SQS notification
- **Endpoint telemetry:** Windows (Sysmon), Linux, and macOS (Unified Log) hosts, shipped via Elastic Agent under Fleet management
- **SIEM:** Elastic, self-hosted single-node on a Terraform-provisioned Proxmox VM
- **Attack emulation:** Stratus Red Team (cloud), Atomic Red Team (endpoints)
- **Detection authoring:** Sigma source with a Palantir ADS-derived strategy doc per rule; compiled to Elastic at deploy time, multi-SIEM compilation as a later extension
- **Deployment:** a thin pySigma-based deploy step pushing rules to the Elastic Detection Engine, with bidirectional metadata sync to git and a shadow-mode (`alerting: false`) burn-in before rules page anyone
- **Response orchestration:** Tines as the SOAR layer, integrated via an outbound push architecture
- **Pipeline health:** synthetic canary detections verifying the ingestion-to-alert path end to end

See [`docs/`](docs/) for ADRs

## Layout

| Directory | Contents |
|---|---|
| `terraform/` | Two Terraform roots: the AWS stack (telemetry sources) and `onprem/` (local SIEM). See `terraform/README.md`. |
| `detections/` | Sigma rules with ADS docs and test fixtures, organized by telemetry source |
| `emulation/` | Stratus and Atomic Red Team configurations |
| `tests/` | Detection test harnesses |
| `ci/` | GitHub Actions workflows |
| `docs/` | ADRs, architecture decisions, research-to-build mapping |
| `scripts/` | Install and operational scripts |

## License

MIT — see [LICENSE](LICENSE).

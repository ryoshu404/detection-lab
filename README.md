# detection-lab

A detection engineering lab built on AWS. Generates real telemetry from CloudTrail, GuardDuty, VPC Flow Logs, and endpoint sources (Sysmon on Windows, Unified Log streaming on macOS). Detection rules are authored in Sigma, validated and deployed via [`pydetect`](https://github.com/ryoshu404/pydetect), and run against a self-hosted Elastic SIEM.

The workflow follows the Detection-as-Code patterns described in Lussier's [Implementing a Modern Detection Engineering Workflow](https://security.googlecloudcommunity.com/community-blog-42/implementing-a-modern-detection-engineering-workflow-part-1-4054), adapted to Sigma source + AWS infrastructure for multi-SIEM portability via [pysigma](https://github.com/SigmaHQ/pySigma).

## Architecture

- **Foundation:** Terraform-managed AWS (IAM, VPC with private subnets, S3 log buckets)
- **Telemetry:** CloudTrail (multi-region with log validation), GuardDuty, VPC Flow Logs, Sysmon, macOS Unified Log
- **Attack emulation:** Stratus Red Team (cloud), Atomic Red Team (endpoints)
- **SIEM:** Elastic self-hosted on a local Proxmox VM (single-node), ingesting AWS telemetry via Filebeat (S3/SQS)
- **Detection authoring:** Sigma source, compiled to target SIEM dialects at deploy time
- **Response orchestration:** Splunk SOAR Community Edition
- **Deployment:** GitHub Actions -> `pydetect deploy.py` -> Elastic, with bidirectional metadata sync
- **Pipeline health:** Lambda canaries verify the end-to-end detection pipeline hourly

See [`docs/`](docs/) for ADRs, architecture decisions, and the research-to-build mapping.

## Layout

| Directory | Contents |
|---|---|
| `terraform/` | Infrastructure modules (`iam`, `networking`, `storage`, `detection`, `siem`) |
| `detections/` | Sigma rules with ADS docs and test fixtures, organized by telemetry source |
| `emulation/` | Stratus and Atomic Red Team configurations |
| `tests/` | Detection test harnesses |
| `ci/` | GitHub Actions workflows |
| `docs/` | Architecture, ADRs, design rationale |
| `scripts/` | Operational tooling |

## License

MIT — see [LICENSE](LICENSE).

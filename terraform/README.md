# Terraform

Two independent Terraform roots, separated by where the infrastructure runs. They share no state; the manual seam between them (the Filebeat/Agent IAM keys hand-carried to the local VM) is documented in ADR-002 and ADR-004.

## AWS stack (this directory)

The top level is the AWS root module. It manages the telemetry sources the lab reads from: CloudTrail (multi-region, log validation), GuardDuty, VPC Flow Logs, the S3 log buckets, and the SQS notification queue, plus the VPC and IAM that support them.

- State: S3 backend (`backend.tf`)
- Auth: `detection-lab` AWS CLI profile
- Modules: `networking`, `storage`, `detection`, `iam` (active); `siem` (retired — see below)

## Local stack (`onprem/`)

The `onprem/` root module provisions the self-hosted Elastic SIEM VM on the local Proxmox host, via the bpg/proxmox provider and cloud-init.

- State: local
- Provider: bpg/proxmox
- See `onprem/README.md` for prerequisites (API token, SSH key, staged cloud image)

## Retired: `modules/siem`

`modules/siem` is the original EC2-hosted Elastic SIEM. It is retained but no longer invoked from `main.tf` — the SIEM moved to local hardware per ADR-002. Kept on the shelf for reference and for anyone who wants the EC2 path.

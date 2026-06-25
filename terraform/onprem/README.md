# terraform/onprem — Local Lab Infrastructure (Proxmox)

## Context

This module manages the on-prem Proxmox host with Terraform, kept separate from
the AWS stack in `../`. It uses a different provider (`bpg/proxmox`) and local
state, and carries no cloud dependency: the lab host can be rebuilt even when
AWS is unreachable. The two stacks are independent — each has its own provider,
its own state, and its own apply lifecycle, and they neither share state nor
reference one another.

The first resource managed here is the Elastic SIEM VM, which replaces the
retired EC2 instance following the decision to host Elastic locally.

## Prerequisites

Three items must be configured on the Proxmox host before the first apply. Each
is a common cause of a failed or confusing run.

- **API token.** Created under Datacenter → Permissions → API Tokens. The token
  requires permission to manage VMs and datastores — either an admin user with
  privilege separation disabled, or a role granting VM and datastore operations.
  The secret is shown only once at creation and is recorded in
  `terraform.tfvars`.
- **Snippets enabled on the `local` datastore.** Set under Datacenter → Storage
  → `local` → Content. Cloud-init is delivered as a snippet, and the upload
  fails without this content type, which is not enabled by default.
- **Key-based SSH to the node.** The provider uploads the cloud-init snippet and
  imports the disk image over SSH/SFTP rather than the API alone, so the node
  must be reachable by key as `root`.

## Usage

```bash
cd terraform/onprem
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform init
terraform plan      # expect 3 resources to add
terraform apply
terraform output elastic_ipv4   # the VM address once the guest agent reports in
```

The VM provisions onto the Hosts/Lab VLAN (vmbr0). Its address is reserved in
UniFi, or pinned via `vm_ip`, so it remains stable.

## Scope

This module provisions a clean, Elastic-ready Ubuntu VM: a login user with our
key, the qemu-guest-agent so the guest reports its address back to Terraform,
and the `vm.max_map_count` tuning Elasticsearch requires. It does not install
Elasticsearch or Kibana. That step is performed separately, after the VM is
verified, so the install remains observable rather than buried in cloud-init.

## Next steps

After apply:

1. SSH to the VM as the provisioned user.
2. Install Elasticsearch and Kibana (single-node, security enabled).
3. Repoint Filebeat at the S3 log buckets using a scoped IAM user, and verify
   CloudTrail ingestion into the local cluster.
4. Decommission the AWS `siem` module and NAT gateway, and record the EC2 → local
   migration in a superseding ADR.

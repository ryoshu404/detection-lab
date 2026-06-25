terraform {
  required_version = ">= 1.5"

  # Local state by design — this stack manages a home-lab host and should carry
  # no cloud dependency. State file is gitignored and covered by machine backup.

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.60"
    }
  }
}

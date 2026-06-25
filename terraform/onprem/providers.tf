provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true

  # Snippet and disk-image uploads go over SSH/SFTP, not the API token alone.
  ssh {
    username    = var.proxmox_ssh_username
    private_key = file(var.proxmox_ssh_private_key_file)
  }
}

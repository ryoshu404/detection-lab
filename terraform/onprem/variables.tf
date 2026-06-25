variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, including scheme and port."
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token, form 'user@realm!tokenid=secret'."
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name."
  type        = string
  default     = "pve"
}

variable "proxmox_ssh_username" {
  description = "SSH user on the node, used by the provider for uploads."
  type        = string
  default     = "root"
}

variable "vm_name" {
  description = "VM name in Proxmox."
  type        = string
  default     = "elastic"
}

variable "vm_vmid" {
  description = "Explicit VMID, or null to auto-assign."
  type        = number
  default     = null
}

variable "vm_cores" {
  description = "vCPU cores."
  type        = number
  default     = 4
}

variable "vm_memory_mb" {
  description = "RAM in MB."
  type        = number
  default     = 8192
}

variable "vm_disk_gb" {
  description = "Root disk size in GB."
  type        = number
  default     = 80
}

variable "vm_datastore" {
  description = "Datastore for the VM disk."
  type        = string
  default     = "local-lvm"
}

variable "vm_bridge" {
  description = "Network bridge."
  type        = string
  default     = "vmbr0"
}

variable "snippet_datastore" {
  description = "Datastore with the Snippets content type enabled."
  type        = string
  default     = "local"
}

variable "vm_image_file_id" {
  description = "Pre-staged cloud image on the node, e.g. local:iso/jammy-server-cloudimg-amd64.img"
  type        = string
  default     = "local:iso/jammy-server-cloudimg-amd64.img"
}

variable "vm_username" {
  description = "Login user created by cloud-init."
  type        = string
  default     = "labadmin"
}

variable "ssh_public_key" {
  description = "SSH public key for the guest user."
  type        = string
}

variable "vm_ip" {
  description = "Static IPv4 in CIDR form, or 'dhcp'."
  type        = string
  default     = "dhcp"
}

variable "vm_gateway" {
  description = "IPv4 gateway, used only when vm_ip is static."
  type        = string
  default     = null
}

variable "proxmox_ssh_private_key_file" {
  description = "Path to the SSH private key for the Proxmox node."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

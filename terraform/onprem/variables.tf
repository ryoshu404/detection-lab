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
  default     = 12288
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

variable "fleet_ctid" {
  description = "Container ID for the Fleet Server LXC."
  type        = number
  default     = 102
}

variable "fleet_hostname" {
  description = "Hostname for the Fleet Server LXC."
  type        = string
  default     = "fleet"
}

variable "fleet_ip" {
  description = "Static IP/CIDR for the Fleet Server LXC on the Hosts VLAN."
  type        = string
  default     = "192.168.1.12/24"
}

variable "fleet_memory_mb" {
  description = "RAM in MB for the Fleet Server LXC."
  type        = number
  default     = 2048
}

variable "fleet_cores" {
  description = "CPU cores for the Fleet Server LXC."
  type        = number
  default     = 2
}

variable "fleet_disk_gb" {
  description = "Root disk size in GB for the Fleet Server LXC."
  type        = number
  default     = 8
}

variable "lxc_template_file_id" {
  description = "Proxmox LXC template volume ID, e.g. local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  type        = string
}

variable "endpoint_hostname" {
  description = "Hostname for the Linux endpoint."
  type        = string
  default     = "linux-endpoint"
}

variable "endpoint_vmid" {
  description = "VMID for the Linux endpoint."
  type        = number
  default     = 103
}

variable "endpoint_ip" {
  description = "Static IP/CIDR for the Linux endpoint on the Hosts VLAN."
  type        = string
  default     = "192.168.1.31/24"
}

variable "endpoint_cores" {
  description = "CPU cores for the Linux endpoint."
  type        = number
  default     = 2
}

variable "endpoint_memory_mb" {
  description = "RAM in MB for the Linux endpoint."
  type        = number
  default     = 3072
}

variable "endpoint_disk_gb" {
  description = "Disk size in GB for the Linux endpoint."
  type        = number
  default     = 20
}

variable "proxmox_node_2" {
  description = "Second Proxmox node; hosts detection targets."
  type        = string
  default     = "pve2"
}

variable "builder_hostname" {
  description = "Hostname for the build/CI container."
  type        = string
  default     = "builder"
}

variable "builder_ctid" {
  description = "Container ID for the build/CI container."
  type        = number
  default     = 104
}

variable "builder_ip" {
  description = "Static IP/CIDR for the build/CI container."
  type        = string
  default     = "192.168.1.32/24"
}

variable "builder_cores" {
  description = "CPU cores for the build/CI container."
  type        = number
  default     = 2
}

variable "builder_memory_mb" {
  description = "RAM in MB for the build/CI container."
  type        = number
  default     = 2048
}

variable "builder_disk_gb" {
  description = "Root disk size in GB for the build/CI container."
  type        = number
  default     = 20
}

variable "windows_template_vmid" {
  description = "VMID of the Packer-built Windows 11 template."
  type        = number
  default     = 9000
}

variable "win_endpoint_hostname" {
  description = "Name for the Windows endpoint VM."
  type        = string
  default     = "win-endpoint"
}

variable "win_endpoint_vmid" {
  description = "VMID for the Windows endpoint."
  type        = number
  default     = 105
}

variable "win_endpoint_cores" {
  description = "CPU cores for the Windows endpoint."
  type        = number
  default     = 4
}

variable "win_endpoint_memory_mb" {
  description = "RAM in MB for the Windows endpoint."
  type        = number
  default     = 8192
}

variable "ghosts_hostname" {
  description = "Hostname for the GHOSTS server."
  type        = string
  default     = "ghosts"
}

variable "ghosts_vmid" {
  description = "VMID for the GHOSTS server."
  type        = number
  default     = 106
}

variable "ghosts_ip" {
  description = "Static IP/CIDR for the GHOSTS server."
  type        = string
  default     = "192.168.1.34/24"
}

variable "ghosts_cores" {
  description = "CPU cores for the GHOSTS server."
  type        = number
  default     = 2
}

variable "ghosts_memory_mb" {
  description = "RAM in MB for the GHOSTS server."
  type        = number
  default     = 6144
}

variable "ghosts_disk_gb" {
  description = "Disk size in GB for the GHOSTS server."
  type        = number
  default     = 40
}

variable "proxmox_url" {
  description = "Proxmox API endpoint, e.g. https://192.168.1.30:8006/api2/json"
  type        = string
}

variable "proxmox_username" {
  description = "API token ID, e.g. terraform@pve!tf"
  type        = string
}

variable "proxmox_token" {
  description = "API token secret."
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Node to build on."
  type        = string
  default     = "pve2"
}

variable "vm_id" {
  description = "VMID for the build VM and resulting template."
  type        = number
  default     = 9000
}

variable "vm_name" {
  description = "Name of the build VM."
  type        = string
  default     = "windows11-build"
}

variable "template_name" {
  description = "Name of the resulting template."
  type        = string
  default     = "windows11-endpoint"
}

variable "storage_pool" {
  description = "Storage for the VM disk, EFI vars, and TPM state."
  type        = string
  default     = "local-lvm"
}

variable "iso_storage_pool" {
  description = "Storage that accepts ISO uploads (needs the ISO content type)."
  type        = string
  default     = "local"
}

variable "vm_bridge" {
  description = "Network bridge."
  type        = string
  default     = "vmbr0"
}

variable "vm_cores" {
  description = "CPU cores for the build VM."
  type        = number
  default     = 4
}

variable "vm_memory_mb" {
  description = "RAM in MB for the build VM."
  type        = number
  default     = 8192
}

variable "vm_disk_size" {
  description = "Disk size. Windows 11 requires at least 64G."
  type        = string
  default     = "100G"
}

variable "windows_iso" {
  description = "Windows 11 ISO on the node, e.g. local:iso/Win11_25H2_English_x64_v2.iso"
  type        = string
}

variable "virtio_iso" {
  description = "VirtIO driver ISO on the node, e.g. local:iso/virtio-win.iso"
  type        = string
}

variable "admin_password" {
  description = "Local Administrator password, set by the answer file and used for WinRM."
  type        = string
  sensitive   = true
}

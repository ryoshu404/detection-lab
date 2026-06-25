output "elastic_vm_id" {
  description = "Proxmox VMID."
  value       = proxmox_virtual_environment_vm.elastic.vm_id
}

output "elastic_vm_name" {
  description = "VM name."
  value       = proxmox_virtual_environment_vm.elastic.name
}

output "elastic_ipv4" {
  description = "IPv4 reported by the guest agent."
  value       = try(proxmox_virtual_environment_vm.elastic.ipv4_addresses[1][0], "pending guest agent")
}

output "filebeat_local_access_key_id" {
  value = module.iam.filebeat_local_access_key_id
}

output "filebeat_local_secret_access_key" {
  value     = module.iam.filebeat_local_secret_access_key
  sensitive = true
}

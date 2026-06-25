# OS prep only — the Elasticsearch/Kibana install is a separate, verified step.
resource "proxmox_virtual_environment_file" "elastic_cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.proxmox_node

  source_raw {
    file_name = "elastic-cloud-init.yaml"
    data      = <<-EOT
      #cloud-config
      hostname: ${var.vm_name}
      users:
        - name: ${var.vm_username}
          groups: [sudo]
          shell: /bin/bash
          sudo: ALL=(ALL) NOPASSWD:ALL
          ssh_authorized_keys:
            - ${var.ssh_public_key}
      package_update: true
      packages:
        - qemu-guest-agent
        - curl
        - gnupg
        - apt-transport-https
      write_files:
        - path: /etc/sysctl.d/99-elasticsearch.conf
          content: |
            vm.max_map_count=262144
      runcmd:
        - systemctl enable --now qemu-guest-agent
        - sysctl --system
      EOT
  }
}

resource "proxmox_virtual_environment_vm" "elastic" {
  name      = var.vm_name
  node_name = var.proxmox_node
  vm_id     = var.vm_vmid
  tags      = ["lab", "siem", "terraform"]

  agent {
    enabled = true
  }

  cpu {
    cores = var.vm_cores
    type  = "host"
  }

  memory {
    dedicated = var.vm_memory_mb
  }

  disk {
    datastore_id = var.vm_datastore
    file_id      = var.vm_image_file_id
    interface    = "virtio0"
    size         = var.vm_disk_gb
    iothread     = true
    discard      = "on"
  }

  network_device {
    bridge = var.vm_bridge
  }

  initialization {
    datastore_id      = var.vm_datastore
    user_data_file_id = proxmox_virtual_environment_file.elastic_cloud_init.id

    ip_config {
      ipv4 {
        address = var.vm_ip
        gateway = var.vm_ip == "dhcp" ? null : var.vm_gateway
      }
    }
  }

  lifecycle {
    ignore_changes = [initialization[0].user_account]
  }
}

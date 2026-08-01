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
    ignore_changes = [
      initialization[0].user_account,
      initialization[0].user_data_file_id,
    ]
  }
}

resource "proxmox_virtual_environment_container" "fleet" {
  node_name    = var.proxmox_node
  vm_id        = var.fleet_ctid
  unprivileged = true
  tags         = ["lab", "fleet", "terraform"]

  cpu {
    cores = var.fleet_cores
  }

  memory {
    dedicated = var.fleet_memory_mb
  }

  disk {
    datastore_id = var.vm_datastore
    size         = var.fleet_disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = var.vm_bridge
  }

  operating_system {
    template_file_id = var.lxc_template_file_id
    type             = "debian"
  }

  initialization {
    hostname = var.fleet_hostname

    ip_config {
      ipv4 {
        address = var.fleet_ip
        gateway = var.vm_gateway
      }
    }

    user_account {
      keys = [trimspace(var.ssh_public_key)]
    }
  }
}

resource "proxmox_virtual_environment_file" "linux_endpoint_cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.proxmox_node_2
  source_raw {
    file_name = "linux-endpoint-cloud-init.yaml"
    data      = <<-EOT
      #cloud-config
      hostname: ${var.endpoint_hostname}
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
      runcmd:
        - systemctl enable --now qemu-guest-agent
      EOT
  }
}

resource "proxmox_virtual_environment_vm" "linux_endpoint" {
  name      = var.endpoint_hostname
  node_name = var.proxmox_node_2
  vm_id     = var.endpoint_vmid
  tags      = ["lab", "endpoint", "linux", "terraform"]

  agent {
    enabled = true
  }
  cpu {
    cores = var.endpoint_cores
    type  = "host"
  }
  memory {
    dedicated = var.endpoint_memory_mb
  }
  disk {
    datastore_id = var.vm_datastore
    file_id      = var.vm_image_file_id
    interface    = "virtio0"
    size         = var.endpoint_disk_gb
    iothread     = true
    discard      = "on"
  }
  network_device {
    bridge = var.vm_bridge
  }
  initialization {
    datastore_id      = var.vm_datastore
    user_data_file_id = proxmox_virtual_environment_file.linux_endpoint_cloud_init.id
    ip_config {
      ipv4 {
        address = var.endpoint_ip
        gateway = var.vm_gateway
      }
    }
  }
  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
      initialization[0].user_data_file_id,
    ]
  }
}

resource "proxmox_virtual_environment_container" "builder" {
  node_name    = var.proxmox_node_2
  vm_id        = var.builder_ctid
  unprivileged = true
  tags         = ["lab", "builder", "ci", "terraform"]

  cpu {
    cores = var.builder_cores
  }
  memory {
    dedicated = var.builder_memory_mb
  }
  disk {
    datastore_id = var.vm_datastore
    size         = var.builder_disk_gb
  }
  network_interface {
    name   = "eth0"
    bridge = var.vm_bridge
  }
  operating_system {
    template_file_id = var.lxc_template_file_id
    type             = "debian"
  }
  initialization {
    hostname = var.builder_hostname
    ip_config {
      ipv4 {
        address = var.builder_ip
        gateway = var.vm_gateway
      }
    }
    user_account {
      keys = [trimspace(var.ssh_public_key)]
    }
  }
}

# Cloned from the Packer-built template (see packer/windows). No cloud-init
# block: Windows has no equivalent, so hostname comes from the answer file
# and the address from a DHCP reservation.
resource "proxmox_virtual_environment_vm" "windows_endpoint" {
  name      = var.win_endpoint_hostname
  node_name = var.proxmox_node_2
  vm_id     = var.win_endpoint_vmid
  tags      = ["lab", "endpoint", "windows", "terraform"]

  bios    = "ovmf"
  machine = "q35"

  clone {
    vm_id = var.windows_template_vmid
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.win_endpoint_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.win_endpoint_memory_mb
  }

  efi_disk {
    datastore_id      = var.vm_datastore
    type              = "4m"
    pre_enrolled_keys = true
  }

  tpm_state {
    datastore_id = var.vm_datastore
    version      = "v2.0"
  }

  network_device {
    bridge = var.vm_bridge
    model  = "virtio"
  }
}

# GHOSTS server: benign user-activity simulation, feeding realistic baseline
# noise to the endpoints so detections are tuned against something other than
# silence. Runs as a VM rather than an LXC because the API stack is five Docker
# containers, and Docker in an unprivileged container needs nesting enabled.
resource "proxmox_virtual_environment_file" "ghosts_cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.proxmox_node_2
  source_raw {
    file_name = "ghosts-cloud-init.yaml"
    data      = <<-EOT
      #cloud-config
      hostname: ${var.ghosts_hostname}
      users:
        - name: ${var.vm_username}
          groups: [sudo, docker]
          shell: /bin/bash
          sudo: ALL=(ALL) NOPASSWD:ALL
          ssh_authorized_keys:
            - ${var.ssh_public_key}
      package_update: true
      packages:
        - qemu-guest-agent
        - curl
        - git
        - ca-certificates
      runcmd:
        - systemctl enable --now qemu-guest-agent
        - curl -fsSL https://get.docker.com | sh
        - usermod -aG docker ${var.vm_username}
      EOT
  }
}

resource "proxmox_virtual_environment_vm" "ghosts" {
  name      = var.ghosts_hostname
  node_name = var.proxmox_node_2
  vm_id     = var.ghosts_vmid
  tags      = ["lab", "tooling", "ghosts", "terraform"]

  agent {
    enabled = true
  }
  cpu {
    cores = var.ghosts_cores
    type  = "host"
  }
  memory {
    dedicated = var.ghosts_memory_mb
  }
  disk {
    datastore_id = var.vm_datastore
    file_id      = var.vm_image_file_id
    interface    = "virtio0"
    size         = var.ghosts_disk_gb
    iothread     = true
    discard      = "on"
  }
  network_device {
    bridge = var.vm_bridge
  }
  initialization {
    datastore_id      = var.vm_datastore
    user_data_file_id = proxmox_virtual_environment_file.ghosts_cloud_init.id
    ip_config {
      ipv4 {
        address = var.ghosts_ip
        gateway = var.vm_gateway
      }
    }
  }
  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
      initialization[0].user_data_file_id,
    ]
  }
}

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "windows11" {
  # --- Proxmox connection ---
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  # --- VM identity ---
  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_name        = var.template_name
  template_description = "Windows 11 endpoint, Sysmon (sysmon-modular). Built {{ isotime \"2006-01-02\" }}"
  os                   = "win11"

  # --- Firmware: UEFI + Secure Boot + TPM 2.0 (Win11 requirements) ---
  bios    = "ovmf"
  machine = "q35"

  efi_config {
    efi_storage_pool  = var.storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  tpm_config {
    tpm_storage_pool = var.storage_pool
    version          = "v2.0"
  }

  # --- Resources ---
  cores  = var.vm_cores
  memory = var.vm_memory_mb

  scsi_controller = "virtio-scsi-single"

  disks {
    type         = "scsi"
    disk_size    = var.vm_disk_size
    storage_pool = var.storage_pool
    format       = "raw"
    cache_mode   = "none"
    io_thread    = true
  }

  network_adapters {
    model  = "virtio"
    bridge = var.vm_bridge
  }

  # --- Install media ---
  boot_iso {
    type     = "sata"
    iso_file = var.windows_iso
    unmount  = true
  }

  # Answer file + provisioning scripts, built into an ISO by Packer.
  # Proxmox has no floppy support, so this is how Windows Setup finds
  # Autounattend.xml.
  additional_iso_files {
    device           = "sata1"
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
    cd_files = [
      "./answer_files/Autounattend.xml",
      "./scripts/enable-winrm.ps1",
    ]
  }

  # VirtIO drivers — Windows Setup cannot see a virtio disk or NIC without
  # these, and no network means Packer can never connect.
  additional_iso_files {
    device   = "sata2"
    iso_file = var.virtio_iso
    unmount  = true
  }

  # --- Boot ---
  # Clears the "Press any key to boot from CD or DVD" prompt. If the build
  # stalls at a black screen, this is the first thing to adjust.
  boot_wait    = "3s"
  boot_command = ["<spacebar>"]

  # --- Communicator ---
  # WinRM is enabled by enable-winrm.ps1, run from the answer file's
  # FirstLogonCommands. Timeout is generous: Windows Setup plus updates
  # is slow.
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = var.admin_password
  winrm_timeout  = "2h"
  winrm_port     = 5985
  winrm_use_ssl  = false
  winrm_insecure = true
}

build {
  sources = ["source.proxmox-iso.windows11"]

  provisioner "powershell" {
    scripts = [
      "./scripts/install-sysmon.ps1",
    ]
  }

  provisioner "powershell" {
    inline = ["Write-Host 'Provisioning complete.'"]
  }
}

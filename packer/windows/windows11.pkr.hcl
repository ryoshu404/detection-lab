packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.2"
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
  template_description = "Windows 11 Pro endpoint, Sysmon (sysmon-modular). Built ${formatdate("YYYY-MM-DD", timestamp())}"
  os                   = "win11"

  # --- CPU ---
  # kvm64 (the default) lacks POPCNT and SSE4.2, which Windows 11 24H2+
  # requires. Booting the installer with it fails silently: the bootloader
  # starts, fails its CPU check, and returns to firmware.
  cpu_type = "x86-64-v2-AES"
  cores    = var.vm_cores
  sockets  = 1
  memory   = var.vm_memory_mb

  machine    = "q35"
  qemu_agent = true

  # --- Firmware: UEFI + Secure Boot + TPM 2.0 ---
  bios = "ovmf"

  efi_config {
    efi_storage_pool  = var.storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  tpm_config {
    tpm_storage_pool = var.storage_pool
    tpm_version      = "v2.0"
  }

  # --- Disk ---
  disks {
    type         = "sata"
    storage_pool = var.storage_pool
    disk_size    = var.vm_disk_size
    cache_mode   = "writeback"
    discard      = true
  }

  # --- Network ---
  network_adapters {
    model  = "e1000"
    bridge = var.vm_bridge
  }

  vga {
    type = "qxl"
  }

  # --- Install media ---
  # Everything on IDE. The boot ISO takes ide0, so the answer file and
  # VirtIO drivers follow on ide1 and ide2.
  boot_iso {
    type         = "ide"
    index        = 0
    iso_file     = var.windows_iso
    iso_checksum = "none"
    unmount      = true
  }

  # Answer file plus first-boot scripts. Proxmox has no floppy support, so
  # Packer builds these into an ISO. The cidata label lets scripts find the
  # volume without assuming a drive letter.
  additional_iso_files {
    type              = "ide"
    index             = 1
    iso_storage_pool  = var.iso_storage_pool
    cd_label          = "cidata"
    unmount           = true
    keep_cdrom_device = false
    cd_files = [
      "./answer_files/Autounattend.xml",
      "./scripts/enable-winrm.ps1",
    ]
  }

  # Kept mounted for the post-install guest tools, not for Setup.
  additional_iso_files {
    type         = "ide"
    index        = 2
    iso_file     = var.virtio_iso
    iso_checksum = "none"
    unmount      = true
  }

  # --- Boot ---
  # Enter, not space: the "press any key" prompt does not reliably accept
  # space through QEMU's virtual keyboard.
  boot         = "order=sata;ide0"
  boot_wait    = "5s"
  boot_command = ["<enter><enter>"]

  # --- Communicator ---
  # WinRM is brought up by enable-winrm.ps1, run from the answer file's
  # FirstLogonCommands. Nothing connects until that runs.
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
    scripts = ["./scripts/install-sysmon.ps1"]
  }
}

# Brings up WinRM so Packer can connect. Run from the answer file's
# FirstLogonCommands; the build waits until this completes.
#
# HTTP with basic auth and unencrypted traffic is acceptable here: the VM
# exists for the duration of the build on an isolated lab bridge.

$ErrorActionPreference = "Stop"

Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue

winrm quickconfig -quiet -force

winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'
winrm set winrm/config '@{MaxTimeoutms="7200000"}'

Enable-PSRemoting -Force -SkipNetworkProfileCheck

New-NetFirewallRule -DisplayName "WinRM HTTP (lab)" -Direction Inbound `
  -LocalPort 5985 -Protocol TCP -Action Allow -Profile Any -ErrorAction SilentlyContinue

Set-Service -Name WinRM -StartupType Automatic
Restart-Service WinRM

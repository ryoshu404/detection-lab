# Sysmon with olafhartong/sysmon-modular.
#
# The config is deliberately permissive. This is a detection lab: events
# filtered at the sensor cannot be recovered downstream, so visibility is
# preferred over volume control. Volume is managed with ILM on the Elastic
# side instead.

$ErrorActionPreference = "Stop"
$work = "C:\Windows\Temp\sysmon"
New-Item -ItemType Directory -Path $work -Force | Out-Null

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" `
  -OutFile "$work\Sysmon.zip" -UseBasicParsing
Expand-Archive -Path "$work\Sysmon.zip" -DestinationPath $work -Force

Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml" `
  -OutFile "$work\sysmonconfig.xml" -UseBasicParsing

& "$work\Sysmon64.exe" -accepteula -i "$work\sysmonconfig.xml"

Start-Sleep -Seconds 5
$svc = Get-Service -Name Sysmon64 -ErrorAction SilentlyContinue
if (-not $svc -or $svc.Status -ne "Running") {
    throw "Sysmon did not install or is not running"
}
Write-Host "Sysmon installed: $($svc.Status)"

Remove-Item -Path "$work\Sysmon.zip" -Force -ErrorAction SilentlyContinue

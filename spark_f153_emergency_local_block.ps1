$ErrorActionPreference = 'Stop'

$remoteIp = '100.74.98.13'
$rules = @(
  'Block spark-f153 Tailscale Inbound',
  'Block spark-f153 Tailscale Outbound'
)

Write-Host "Remote IP: $remoteIp"

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Please run this script in an elevated PowerShell window.'
}

if (-not (Get-NetFirewallRule -DisplayName $rules[0] -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName $rules[0] -Direction Inbound -Action Block -RemoteAddress $remoteIp -Profile Any | Out-Null
}

if (-not (Get-NetFirewallRule -DisplayName $rules[1] -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName $rules[1] -Direction Outbound -Action Block -RemoteAddress $remoteIp -Profile Any | Out-Null
}

Get-NetFirewallRule -DisplayName $rules | Get-NetFirewallAddressFilter | Select-Object Name, RemoteAddress

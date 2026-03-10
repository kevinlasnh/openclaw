# Self-Elevating OpenSSH Server Installation Script
# Will auto-request admin via UAC if needed

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    # Relaunch this script with admin privileges
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Running as Admin from here
Write-Host "Running as Administrator" -ForegroundColor Green

$sshdPath = "$env:WINDIR\System32\OpenSSH\sshd.exe"

Write-Host "`n=== Checking sshd.exe ===" -ForegroundColor Cyan
if (!(Test-Path $sshdPath)) {
    Write-Host "ERROR: sshd.exe not found!" -ForegroundColor Red
    pause
    exit 1
}
Write-Host "OK: sshd.exe exists" -ForegroundColor Green

Write-Host "`n=== Creating sshd service ===" -ForegroundColor Cyan
$result = sc.exe create sshd binPath= "$sshdPath" start= auto DisplayName= "OpenSSH SSH Server"
Write-Host $result

Write-Host "`n=== Setting service description ===" -ForegroundColor Cyan
sc.exe description sshd "OpenSSH SSH Server"

Write-Host "`n=== Starting sshd service ===" -ForegroundColor Cyan
try {
    Start-Service sshd -ErrorAction Stop
    Write-Host "sshd started successfully" -ForegroundColor Green
} catch {
    Write-Host "Start failed: $_" -ForegroundColor Yellow
}

Write-Host "`n=== Configuring firewall ===" -ForegroundColor Cyan
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null
Write-Host "Firewall rule configured" -ForegroundColor Green

Write-Host "`n=== Final Status ===" -ForegroundColor Cyan
Get-Service -Name sshd, ssh-agent | Format-Table Name, Status, StartType

Start-Sleep -Seconds 1
Write-Host "`n=== Port 22 Status ===" -ForegroundColor Cyan
Get-NetTCPConnection -LocalPort 22 -ErrorAction SilentlyContinue | Format-Table

Write-Host "`nDone!" -ForegroundColor Green
pause

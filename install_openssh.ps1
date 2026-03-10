# OpenSSH Server Service Installation Script for Windows 11
# Run as Administrator

$sshdPath = "$env:WINDIR\System32\OpenSSH\sshd.exe"

Write-Host "=== Checking if sshd.exe exists ===" -ForegroundColor Cyan
if (!(Test-Path $sshdPath)) {
    Write-Host "ERROR: sshd.exe not found!" -ForegroundColor Red
    exit 1
}
Write-Host "OK: sshd.exe found" -ForegroundColor Green

Write-Host "`n=== Creating sshd service ===" -ForegroundColor Cyan
try {
    sc.exe create sshd binPath= "$sshdPath" start= auto DisplayName= "OpenSSH SSH Server"
    Write-Host "Service created successfully" -ForegroundColor Green
} catch {
    Write-Host "Note: $_" -ForegroundColor Yellow
}

Write-Host "`n=== Setting service description ===" -ForegroundColor Cyan
sc.exe description sshd "OpenSSH SSH Server"

Write-Host "`n=== Starting sshd service ===" -ForegroundColor Cyan
try {
    Start-Service sshd
    Write-Host "sshd started" -ForegroundColor Green
} catch {
    Write-Host "Start failed: $_" -ForegroundColor Yellow
}

Write-Host "`n=== Configuring firewall ===" -ForegroundColor Cyan
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null

Write-Host "`n=== Service Status ===" -ForegroundColor Cyan
Get-Service -Name sshd, ssh-agent | Format-Table Name, Status, StartType

Write-Host "`n=== Port Listening Check ===" -ForegroundColor Cyan
Start-Sleep -Seconds 1
Get-NetTCPConnection -LocalPort 22 -ErrorAction SilentlyContinue | Format-Table

Write-Host "`nDone!" -ForegroundColor Green

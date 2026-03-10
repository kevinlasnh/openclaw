if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
Stop-Service sshd -ErrorAction SilentlyContinue
Start-Sleep 1
Write-Host "sshd debug mode on port 22. Connect from phone now. Ctrl+C to stop."
& "C:\Windows\System32\OpenSSH\sshd.exe" -ddd -p 22 2>&1 | Tee-Object "C:\Zero\Doc\Cloud\GitHub\OpenClaw\sshd_debug.txt"

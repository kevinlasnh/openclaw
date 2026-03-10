if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$out = "C:\Zero\Doc\Cloud\GitHub\OpenClaw\sshd_fix_output.txt"
"=== sshd repair $(Get-Date) ===" | Out-File $out

# 1. Fix host key permissions
"--- Fixing host key permissions ---" | Out-File $out -Append
$keys = Get-ChildItem C:\ProgramData\ssh\ssh_host_*_key
foreach ($k in $keys) {
    icacls $k.FullName /inheritance:r /grant "SYSTEM:(R)" /grant "Administrators:(R)" 2>&1 | Out-File $out -Append
}

# 2. Fix administrators_authorized_keys permissions
"--- Fixing administrators_authorized_keys ---" | Out-File $out -Append
$ak = "C:\ProgramData\ssh\administrators_authorized_keys"
if (Test-Path $ak) {
    icacls $ak /inheritance:r /grant "SYSTEM:(R)" /grant "Administrators:(R)" 2>&1 | Out-File $out -Append
}

# 3. Restart sshd
"--- Restarting sshd ---" | Out-File $out -Append
Restart-Service sshd 2>&1 | Out-File $out -Append
Get-Service sshd | Out-File $out -Append

# 4. Test config
"--- Config test ---" | Out-File $out -Append
& "C:\Windows\System32\OpenSSH\sshd.exe" -t 2>&1 | Out-File $out -Append

"=== Done ===" | Out-File $out -Append
Get-Content $out
Write-Host "`nPress any key to close."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

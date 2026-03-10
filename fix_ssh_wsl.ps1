if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ak = "C:\ProgramData\ssh\administrators_authorized_keys"
$wslKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCXNINKLFEB8zUtwX9txzBp+Qm6EqnT5rUgYjHH8g6Z7FGul1OVLtZ3Rmc8Ox+4lfSTEz5hH6XJU8SDwlY1P58kpyNW0N3KbLcl5OchufvNom7v3m9Np6fL5R7ZUcDFnqUL+2rnjmgPFdhEMoaLMbfIAm1yKgqSXFUbYbg+0IWLnMGoXzlbKT1t30PFU/fh1+ftvaL+Z8nwHLP3QS5n/OGkP2I38/dkauG6uxlRf3L9gX3va2a6wW1yZgVk1a1HtrwwBP3nwNsRoLDIS34NPQNiKOHxdTh4gNyKYx2XK45VZImRfvO/UVuEOlpIczMGYWeLGpi9KOXHuv9wk+Q8CVXJdVNJUWXs9jbKOjkVejiahusdl/2H5m5x9CIusxIOASDvaqI19pNPXtd8Sf8zKGIlhoznWLXcRB/+agIf+pVjMad5S5gSaYuTVYSzLiBxuwIfGd6cTEBe4bhxmAasNGqYCTGoIAas/UgweZfR9uYQ/+VkQeFPQRvKwlybJ/eZEFcN4hZ4glQL7Fkt/BdqMpbEBaucDQlZH62K+TMNUxbiqGC/IR82CVIRShntOrQdMTDwFl/1wMRv4BU7dXzyoT2OgDlnBIE24hIAjseaVQhjbr3nQw+u7guRLAqIXJYNYkfr+KPPrXksF6j6eFqKyow4xHngOd+bKv/luMEAQvtwdQ== openclaw@wsl"

# Append key if not already present
if (Test-Path $ak) {
    $content = Get-Content $ak -Raw
    if ($content -notmatch "openclaw@wsl") {
        Add-Content $ak "`n$wslKey"
        Write-Host "WSL key appended."
    } else {
        Write-Host "WSL key already exists, skipping."
    }
} else {
    Set-Content $ak $wslKey
    Write-Host "Created file with WSL key."
}

# Fix permissions
icacls $ak /inheritance:r /grant "SYSTEM:(R)" /grant "BUILTIN\Administrators:(R)" 2>&1
Write-Host "`nDone. Press any key to close."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

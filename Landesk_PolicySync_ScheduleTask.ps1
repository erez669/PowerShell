If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
  Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
  Exit
}

Clear-Host

$ErrorActionPreference = 'SilentlyContinue'

# Detect OS architecture
$arch = [System.Environment]::Is64BitOperatingSystem
$progFiles = if ($arch) { 'C:\Program Files (x86)' } else { 'C:\Program Files' }

# Concatenate the path
$taskPath = $progFiles + '\LANDesk\LDClient\PolicySync.exe'

# Create the scheduled task
SCHTASKS /Delete /TN "LANDESK PolicySync" /F
SCHTASKS /Create /TN "LANDESK PolicySync" /TR "'$taskPath'" /SC HOURLY /MO 3 /RU "NT AUTHORITY\SYSTEM"

# Run the task immediately
# SCHTASKS /Run /TN "LANDESK PolicySync"
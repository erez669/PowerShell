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

# Check if the task exists
$taskExist = SCHTASKS /Query /TN "LANDESK PolicySync"

# Delete the task if it exists
if ($taskExist -like "*LANDESK PolicySync*") {
    SCHTASKS /Delete /TN "LANDESK PolicySync" /F
}

# Create the task
SCHTASKS /Create /TN "LANDESK PolicySync" /TR "'$taskPath'" /SC HOURLY /ST 02:00 /RU "NT AUTHORITY\SYSTEM" /MO 2

# Run the task immediately
# SCHTASKS /Run /TN "LANDESK PolicySync"

# Initialize log file
$logFile = "C:\Install\PolicySync_log.txt"

# Function to append to log
function Write-Log {
    Param (
        [string]$message
    )
    Add-Content $logFile -Value "$(Get-Date) - $message"
}

# Check for Admin privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Log "Not running as an admin. Attempting to run as admin."
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

# Detect OS architecture
$arch = [System.Environment]::Is64BitOperatingSystem
$progFiles = if ($arch) { 'C:\Program Files (x86)' } else { 'C:\Program Files' }
$taskPath = Join-Path $progFiles 'LANDesk\LDClient\PolicySync.exe'

# Check if the task exists
$taskExist = & SCHTASKS /Query /TN "LANDESK PolicySync" 2>&1
if ($taskExist -like "*LANDESK PolicySync*") {
    Write-Log "Task exists. Deleting."
    $deleteResult = & SCHTASKS /Delete /TN "LANDESK PolicySync" /F 2>&1
    Write-Log "Delete Result: $deleteResult"
}

# Create the task
$createResult = & SCHTASKS /Create /TN "LANDESK PolicySync" /TR "$taskPath" /SC HOURLY /ST 02:00 /RU "NT AUTHORITY\SYSTEM" /MO 2 2>&1
Write-Log "Create Result: $createResult"

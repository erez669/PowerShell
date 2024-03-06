<#
.SYNOPSIS
This script performs administrative tasks and updates the hosts file with specific entries based on the computer's name.

.DESCRIPTION
This PowerShell script checks if it's running with administrative privileges and restarts itself as an administrator if not. 
It then determines the computer's SNIF based on its name, calculates IP address segments, and updates the hosts file with predefined entries.

.EXAMPLE
PS> .\Update_Hosts_File_on_Snif.ps1
Executes the script, requiring administrative privileges, and updates the hosts file based on the system's name.

.NOTES
Ensure this script is run in an environment where administrative privileges can be obtained. 
It's designed to work on systems following specific naming conventions (LP and POS).

#>

If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}

# Determine the directory where the script is located
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -Path $scriptPath

# Determine the SNIF based on the computer's name
if ($env:computername.Substring(1, 2) -eq "LP") {
    $snif = $env:computername.Substring(8, 3)
} elseif ($env:computername.Substring(0, 3) -eq "POS") {
    $snif = $env:computername.Substring(4, 3)
}

# Check if SNIF contains 888 or if the IP address is 10.18.88.x or 10.118.88.x
if ($snif.Contains("888") -or $env:computername -like "10.18.88.*" -or $env:computername -like "10.118.88.*") {
    Write-Host "SNIF 888 integration was detected, hosts file was not changed."
    exit 0
}

$ipa = $snif.Substring(0, 1)
$ipb = $snif.Substring(1, 2)
if ($ipb -lt 10) {
    $ipb = $ipb.Substring(1, 1)
}

$ipvl1 = "10.1$ipa.$ipb."
$ipvl2 = "10.11$ipa.$ipb."

# Define the new entries to add to the hosts file
$newEntries = @(
    "$($ipvl1)10      POSNLB$snif.posprod.supersol.co.il",
    "$($ipvl1)1       PLPOSSRV$snif.posprod.supersol.co.il",
    "$($ipvl1)2       SLPOSSRV$snif.posprod.supersol.co.il",
    "$($ipvl2)9       WLPOSSRV$snif.posprod.supersol.co.il",
    "10.250.238.21    MPRETALIXSQL1",
    "10.250.238.22    MPRETALIXSQL2",
    "10.250.238.11    RETALIXSQL1",
    "10.250.238.12    RETALIXSQL2"
)

# Get the path to the hosts file
$hostsPath = "$env:windir\System32\drivers\etc\hosts"

# Read the current content of the hosts file line by line and convert it to a single string
$currentContentArray = Get-Content -Path $hostsPath
$currentContent = $currentContentArray -join "`r`n"

# Check for null or empty content before trimming
if (![string]::IsNullOrEmpty($currentContent)) {
    # Remove all trailing newlines or return characters
    while ($currentContent.EndsWith("`r") -or $currentContent.EndsWith("`n")) {
        $currentContent = $currentContent.TrimEnd("`r", "`n")
    }
}

# Calculate the maximum length of the IP addresses to align the columns
$ipMaxLength = 0
foreach ($entry in $newEntries) {
    $ipLength = $entry.Split(' ')[0].Length
    if ($ipLength -gt $ipMaxLength) {
        $ipMaxLength = $ipLength
    }
}
$ipMaxLength += 8  # Add additional padding for better visibility

# Initialize a variable to store any new entries that need to be added
$newEntriesToAdd = @()
$entriesModified = $false

foreach ($entry in $newEntries) {
    # Split the entry into IP and host name parts
    $parts = $entry -split '\s+', 2
    $ip = $parts[0]
    $hostName = $parts[1].Trim()

    # Format the entry with padding to align the columns
    $formattedEntry = $ip.PadRight($ipMaxLength) + $hostName

    # Check if the entry already exists in the hosts file
    if ($currentContent -notmatch [regex]::Escape($formattedEntry)) {
        # Entry not found, prepare to add to the hosts file
        $newEntriesToAdd += $formattedEntry
        $entriesModified = $true
    }
}

# Check if there are new entries to add
if ($entriesModified) {
    # Combine all new entries into a single string with new lines
    $formattedEntriesToAdd = $newEntriesToAdd -join "`r`n"

    # Check for null or empty content before appending
    if (-not [string]::IsNullOrEmpty($currentContent)) {
        if (-not $currentContent.EndsWith("`r`n")) {
            $currentContent += "`r`n"
        }
    }

    # Add the new entries to the current content
    $currentContent += "`r`n" + $formattedEntriesToAdd

    # Write the updated content back to the hosts file
    [System.IO.File]::WriteAllText($hostsPath, $currentContent)

    # Output the modified hosts file content to the console
    Write-Output $currentContent
} else {
    # No new entries were found that needed to be added, output a message
    Write-Output "Values already exist, file not modified."
}

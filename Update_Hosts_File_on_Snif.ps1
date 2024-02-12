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

$ipa = $snif.Substring(0, 1)
$ipb = $snif.Substring(1, 2)
if ($ipb -lt 10) {
    $ipb = $ipb.Substring(1, 1)
}

$ipvl1 = "10.1$ipa.$ipb."
$ipvl2 = "10.11$ipa.$ipb."

# Define the new entries to add to the hosts file
$newEntries = @(
    "10.14.27.10         POSNLB$snif.posprod.supersol.co.il",
    "10.14.27.1          PLPOSSRV$snif.posprod.supersol.co.il",
    "10.14.27.2          SLPOSSRV$snif.posprod.supersol.co.il",
    "10.114.27.9         WLPOSSRV$snif.posprod.supersol.co.il",
    "10.250.238.21       MPRETALIXSQL1",
    "10.250.238.22       MPRETALIXSQL2",
    "10.250.238.11       RETALIXSQL1",
    "10.250.238.12       RETALIXSQL2"
)

# Get the path to the hosts file and define the backup file path
$hostsPath = "$env:windir\System32\drivers\etc\hosts"
$backupPath = "$hostsPath.bak"

# Read the current content of the hosts file
$currentContent = Get-Content -Path $hostsPath -Raw

# Ensure $newEntries is not null or empty before proceeding
if ($newEntries -and $newEntries.Count -gt 0) {
    # Initialize a variable to store any new entries that need to be added
    $newEntriesToAdd = ""

    foreach ($entry in $newEntries) {
        # Check if the entry already exists in the hosts file
        if (-not ($currentContent -match [regex]::Escape($entry))) {
            # Entry not found, prepare to add to the hosts file
            $newEntriesToAdd += $entry + "`n"
        }
    }

    # Check if there are new entries to add
    if (-not [string]::IsNullOrWhiteSpace($newEntriesToAdd)) {
        $newEntriesToAdd = $newEntriesToAdd.TrimEnd("`n")  # Remove the last new line character

        # If the current content does not end with a newline, add one
        if (-not $currentContent.EndsWith("`n")) {
            $currentContent += "`n"  # Ensure there is a newline before new entries
        }

        # Add a single blank line before adding the new entries
        $currentContent += "`n"

        # Add the new entries
        $currentContent += $newEntriesToAdd  # No additional new line at the end

        # Write the updated content back to the hosts file without a trailing newline
        [System.IO.File]::WriteAllText($hostsPath, $currentContent)

        # Output the modified hosts file content to the console
        Write-Output $currentContent
    } else {
        Write-Output "Values already exist in the hosts file."
    }
}

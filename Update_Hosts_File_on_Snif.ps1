If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
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

# Read the current content of the hosts file
$currentContent = Get-Content -Path $hostsPath

# Define the IPv6 localhost entry
$ipv6LocalhostEntry = "#	::1             localhost"

# Add the IPv6 localhost entry if it doesn't exist
if (-not ($currentContent -contains $ipv6LocalhostEntry)) {
    $currentContent += $ipv6LocalhostEntry
}

# Remove any existing blank lines after the IPv6 localhost entry
$currentContent = $currentContent | Where-Object { $_ -ne "" }

# Add one blank line after the IPv6 localhost entry
$ipv6Index = [array]::IndexOf($currentContent, $ipv6LocalhostEntry)
$currentContent = $currentContent[0..$ipv6Index] + "" + $currentContent[($ipv6Index + 1)..$currentContent.Length]

# Determine the longest IP address length for padding
$maxLength = ($newEntries | ForEach-Object { $_.Split(' ')[0].Length } | Measure-Object -Maximum).Maximum
$formatString = "{0,-$maxLength} {1}"

# Add the new entries to the hosts file with padding
foreach ($entry in $newEntries) {
    $parts = $entry.Split(' ', 2)
    $formattedEntry = $formatString -f $parts[0], $parts[1]
    $currentContent += $formattedEntry
}

# Write the updated content back to the hosts file
$currentContent | Out-File -FilePath $hostsPath -Encoding ASCII

# Output the modified hosts file content to the console (optional)
$currentContent
# Check if running as Administrator
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}

# Enable verbose output
$VerbosePreference = 'Continue'

# LDAP Connection setup
Add-Type -AssemblyName System.DirectoryServices.Protocols
$ldapConnection = New-Object System.DirectoryServices.Protocols.LdapConnection("posprod.supersol.co.il")
$ldapConnection.AuthType = [System.DirectoryServices.Protocols.AuthType]::Ntlm

# Output file
$outputFile = "C:\Scripts\ADResults-v2.txt"
"" | Out-File -FilePath $outputFile -Verbose

# Initialize counters at the global scope
$Global:detectedObjectsCount = 0
$Global:removedObjectsCount = 0

function Write-OutputLog {
    param (
        [string]$message,
        [string]$type = "INFO"
    )
    $formattedMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$type] $message"
    Write-Host $formattedMessage
    $formattedMessage | Out-File -FilePath $outputFile -Append
}

Write-OutputLog "Starting Script Execution"

# Verify LDAP Connection
try {
    $ldapConnection.Bind()
    Write-OutputLog "LDAP Connection established successfully."
} catch {
    Write-OutputLog "Failed to establish LDAP Connection: $_"
    return
}

# Server names and patterns
$serverNames = @("plpossrv751", "slpossrv751", "plpossrv754", "slpossrv754", "plpossrv755", "slpossrv755", "plpossrv756", "slpossrv756", "plpossrv758", "slpossrv758", "plpossrv759", "slpossrv759")
$WitnessNames = @("wlpossrv751", "wlpossrv754", "wlpossrv755", "wlpossrv756", "wlpossrv758", "wlpossrv759")
$wksPattern = "WKS-888*"
$posPattern = "POS-888*"

# Organizational Units (OUs)
$serverOU = "OU=Servers_2019,OU=Branches,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"
$WitnessOU = "OU=witness2k12,OU=Witness,OU=Branches,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"
$wksOU1 = "OU=USB Allowed,OU=PCI_WKS,OU=WorkStations,OU=Branches,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"
$wksOU2 = "OU=USB Restricted,OU=PCI_WKS,OU=WorkStations,OU=Branches,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"
$posOU1 = "OU=USB Allowed,OU=Cachiers,OU=Branches,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"
$posOU2 = "OU=USB Restricted,OU=Cachiers,OU=Branches,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"

function SearchAndPrepare-ADObjects {
    param (
        [string]$name,
        [string]$searchBase
    )
    try {
        Write-OutputLog "Searching for $name in $searchBase"

        $searchRequest = New-Object System.DirectoryServices.Protocols.SearchRequest($searchBase, "(&(objectClass=computer)(name=$name))", 'Subtree', @("distinguishedName"))
        $searchResponse = $ldapConnection.SendRequest($searchRequest)

        if ($searchResponse.Entries.Count -gt 0) {
            $Global:detectedObjectsCount += $searchResponse.Entries.Count
            Write-OutputLog "Search response count for $name : $($searchResponse.Entries.Count)"

            $dn = $searchResponse.Entries[0].DistinguishedName
            $directoryEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$dn")
            $directoryEntry.DeleteTree()
            $directoryEntry.CommitChanges()

            $Global:removedObjectsCount++
            Write-OutputLog "$name successfully marked for deletion."
        } else {
            Write-OutputLog "$name not found in AD."
        }
    } catch {
        Write-OutputLog "Error during processing $name : $_" -type "ERROR"
    }
}

function Get-ComputersByPattern {
    param (
        [string]$pattern,
        [string]$searchBase
    )
    try {
        Write-OutputLog "Searching for computers with pattern $pattern in $searchBase"

        $ldapFilter = "(&(objectClass=computer)(name=$pattern))"
        $searchRequest = New-Object System.DirectoryServices.Protocols.SearchRequest($searchBase, $ldapFilter, 'Subtree', @("name"))
        $searchResponse = $ldapConnection.SendRequest($searchRequest)

        Write-OutputLog "Search response count for pattern $pattern : $($searchResponse.Entries.Count)"

        $searchResponse.Entries | ForEach-Object { $_.Attributes["name"][0] }
    } catch {
        Write-OutputLog "Error occurred during search for computers with pattern $pattern : $_" -type "ERROR"
    }
}

# Process for servers
foreach ($server in $serverNames) {
    Write-OutputLog "Processing server $server"
    SearchAndPrepare-ADObjects -name $server -searchBase $serverOU
}

# Process for Witness Servers
foreach ($object in $WitnessNames) {
    Write-OutputLog "Processing server $object"
    SearchAndPrepare-ADObjects -name $object -searchBase $WitnessOU
}

# Process for workstations and POS
$workstationOUs = @($wksOU1, $wksOU2)
$posOUs = @($posOU1, $posOU2)

Write-OutputLog "Processing Workstations 888"
foreach ($ou in $workstationOUs) {
    Write-OutputLog "Checking OU $ou for workstations"
    $matchingComputers = Get-ComputersByPattern -pattern $wksPattern -searchBase $ou
    foreach ($computer in $matchingComputers) {
        Write-OutputLog "Processing workstation $computer"
        SearchAndPrepare-ADObjects -name $computer -searchBase $ou
    }
}

Write-OutputLog "Processing POS 888 Systems"
foreach ($ou in $posOUs) {
    Write-OutputLog "Checking OU $ou for POS systems"
    $matchingComputers = Get-ComputersByPattern -pattern $posPattern -searchBase $ou
    foreach ($computer in $matchingComputers) {
        Write-OutputLog "Processing POS system $computer"
        SearchAndPrepare-ADObjects -name $computer -searchBase $ou
    }
}

# Script execution summary
Write-OutputLog "Script execution completed."
Write-OutputLog "Total objects detected: $Global:detectedObjectsCount"
Write-OutputLog "Total objects removed: $Global:removedObjectsCount"

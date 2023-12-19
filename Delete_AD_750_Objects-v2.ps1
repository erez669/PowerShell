If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
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

function Write-OutputLog {
    param (
        [string]$message
    )
    Write-Host $message
    $message | Out-File -FilePath $outputFile -Append
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
$wksPattern = "WKS-888*"
$posPattern = "POS-888*"

# Organizational Units (OUs)
$serverOU = "OU=Servers_2019,OU=Branches,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"
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
        $output = "[$(Get-Date)] Searching for $name in $searchBase"
        Write-OutputLog $output

        $searchRequest = New-Object System.DirectoryServices.Protocols.SearchRequest($searchBase, "(&(objectClass=computer)(name=$name))", 'Subtree', @("distinguishedName"))
        $searchResponse = $ldapConnection.SendRequest($searchRequest)

        $output = "[$(Get-Date)] Search response count for ${name}: $($searchResponse.Entries.Count)"
        Write-OutputLog $output

        if ($searchResponse.Entries.Count -gt 0) {
            $dn = $searchResponse.Entries[0].DistinguishedName
            $directoryEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$dn")
            $directoryEntry.DeleteTree()
            $directoryEntry.CommitChanges()

            $output = "[$(Get-Date)] $name successfully marked for deletion."
            Write-OutputLog $output
        } else {
            $output = "[$(Get-Date)] $name not found in AD."
            Write-OutputLog $output
        }
    } catch {
        $output = "[$(Get-Date)] Search response count for ${name}: $($searchResponse.Entries.Count)"
    }
}

function Get-ComputersByPattern {
    param (
        [string]$pattern,
        [string]$searchBase
    )
    try {
        $output = "[$(Get-Date)] Searching for computers with pattern $pattern in $searchBase"
        Write-OutputLog $output

        $ldapFilter = "(&(objectClass=computer)(name=$pattern))"
        $searchRequest = New-Object System.DirectoryServices.Protocols.SearchRequest($searchBase, $ldapFilter, 'Subtree', @("name"))
        $searchResponse = $ldapConnection.SendRequest($searchRequest)

        $output = "[$(Get-Date)] Search response count for ${name}: $($searchResponse.Entries.Count)"
        Write-OutputLog $output

        $searchResponse.Entries | ForEach-Object { $_.Attributes["name"][0] }
    } catch {
        $output = "[$(Get-Date)] Search response count for ${name}: $($searchResponse.Entries.Count)"
    }
}

# Process for servers
foreach ($server in $serverNames) {
    Write-OutputLog "Processing server $server"
    SearchAndPrepare-ADObjects -name $server -searchBase $serverOU
}

# Process for workstations and POS
$workstationOUs = @($wksOU1, $wksOU2)
$posOUs = @($posOU1, $posOU2)

Write-OutputLog "Processing Workstations"
foreach ($ou in $workstationOUs) {
    Write-OutputLog "Checking OU $ou for workstations"
    $matchingComputers = Get-ComputersByPattern -pattern $wksPattern -searchBase $ou
    if ($matchingComputers) {
        foreach ($computer in $matchingComputers) {
            Write-OutputLog "Processing workstation $computer"
            SearchAndPrepare-ADObjects -name $computer -searchBase $ou
        }
    } else {
        Write-OutputLog "No matching workstations found in $ou"
    }
}

Write-OutputLog "Processing POS Systems"
foreach ($ou in $posOUs) {
    Write-OutputLog "Checking OU $ou for POS systems"
    $matchingComputers = Get-ComputersByPattern -pattern $posPattern -searchBase $ou
    if ($matchingComputers) {
        foreach ($computer in $matchingComputers) {
            Write-OutputLog "Processing POS system $computer"
            SearchAndPrepare-ADObjects -name $computer -searchBase $ou
        }
    } else {
        Write-OutputLog "No matching POS systems found in $ou"
    }
}
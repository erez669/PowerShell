$hostname = [System.Environment]::MachineName

if ($hostname -match "^POS-\d{3}-\d{2}-(SCO|WAN|MOD)$") {

  Write-Host "Debug: Matched POS-XYZ-XX-SCO/WAN/MOD hostname format detected, continue with script execution"

  if ((Get-WmiObject Win32_OperatingSystem).Version -like "6.1*") {
    $xmlPath = "C:\Program Files\Retalix\SCO.NET\App\DevicesConfig.xml" 
  } else {
    $xmlPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\DevicesConfig.xml"
  }

} elseif ($hostname -match "^POS-\d{3}-\d{2}-(CSS|WAN|MOD)$") {

  Write-Host "Debug: Matched POS-XYZ-XX-CSS/WAN/MOD hostname format detected, continue with script execution"
  
  $xmlPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\DevicesConfig.xml"

} else {

  Write-Host "Debug: Hostname format did not match, script execution was stopped"
  Exit 9

}

if ([string]::IsNullOrEmpty($xmlPath) -or -not (Test-Path $xmlPath)) {
    Write-Host "XML path is invalid or file does not exist. Exiting."
    Exit
}

# Load XML content from file
$xml = [xml](Get-Content $xmlPath)
Write-Host "XML loaded from: $xmlPath"

# LDAP group search
$computer = Get-WmiObject Win32_ComputerSystem
$branchNumber = $computer.Name.Split('-')[1]
$ldapPath = "LDAP://OU=Branch Groups,OU=Group Objects,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"
$groupCN = "Branch_$branchNumber"
Write-Host "Branch number is $branchNumber"

$dirEntry = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
$search = New-Object System.DirectoryServices.DirectorySearcher($dirEntry)
$search.Filter = "(CN=$groupCN)"
[void]$search.PropertiesToLoad.Add("memberOf")

$group = $search.FindOne()

if ($null -ne $group) {
    $groupMembers = $group.Properties.memberof | ForEach-Object {
        if ($_ -match 'CN=([^,]+)') {
            $matches[1]
        }
    } | Where-Object { $_ -like 'NET_*' }
    $groupMembers = $groupMembers -join ', '
    Write-Host "LDAP Group detected: $groupMembers"
}

# Update Scale if in Net_Supersol_New_Pharm
if ($group.Properties.memberof -like "*Net_Supersol_New_Pharm*") {
    $scaleNode = $xml.Devices.Scale
    if ($null -eq $scaleNode) {
        Write-Host "Scale node not found in XML. Exiting."
        Exit
    }

    $scaleNode.SetAttribute("Active", "false")
    Write-Host "Changed Scale Active attribute to false"
}

# Update the Active attribute for EMV node
$emvNode = $xml.Devices.EMV
if ($null -eq $emvNode) {
    Write-Host "EMV node not found in XML. Exiting."
    Exit
}

$oldValue = $emvNode.GetAttribute("Active")

if ($oldValue -eq "true") {
    Write-Host "Value already true, not changed."
} else {
    $emvNode.SetAttribute("Active", "true")
    Write-Host "Changed EMV Active attribute from $oldValue to true"
}

# Output success message after above check
Write-Host "XML update completed successfully!"

# Save changes to the XML file
$xml.Save($xmlPath)

# Output file path
Write-Host "Updated XML saved to: $xmlPath"

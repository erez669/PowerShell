# Initialize a flag to check if changes were made
$changesMade = $false

# Load XML content from file
Write-Host "Loading XML file..."
$xmlPath = "C:\retalix\wingpos\Files\Devices\EpsonOPOSConfig.xml"
$xml = [xml](Get-Content $xmlPath)

# Get EMV Node
Write-Host "Retrieving EMV settings..."
$emvNode = $xml.POSDevices.POSDeviceList.EMV
$oldEmvValue = $emvNode.active

# Check and set EMV value only if it's not true already
if ($oldEmvValue -eq "true") {
    Write-Host "EMV value already true."
} else {
    Write-Host "Old EMV value: $oldEmvValue"
    Write-Host "Setting EMV to true..."
    $emvNode.active = "true"
    Write-Host "New EMV value set to true."
    $changesMade = $true
}

# Get physical device model using WMI
Write-Host "Fetching device model..."
$deviceModel = (Get-WmiObject Win32_ComputerSystemProduct).Name
Write-Host "Device Model: $deviceModel"

# Update LineDisplay for specific device models
$specialModels = @("4852E70", "4852570", "6200E35")
if ($specialModels -contains $deviceModel) {
    $lineDisplayNode = $xml.POSDevices.POSDeviceList.LineDisplay
    if ($lineDisplayNode.active -ne "false") {
        Write-Host "Special model detected, updating LineDisplay to inactive..."
        $lineDisplayNode.active = "false"
        $changesMade = $true
    } else {
        Write-Host "LineDisplay already set to inactive."
    }
}

# LDAP group search
$computer = Get-WmiObject Win32_ComputerSystem
$branchNumber = $computer.Name.Split('-')[1]
$ldapPath = "LDAP://OU=Branch Groups,OU=Group Objects,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"
$groupCN = "Branch_$branchNumber"

$dirEntry = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
$search = New-Object System.DirectoryServices.DirectorySearcher($dirEntry)
$search.Filter = "(CN=$groupCN)"
[void]$search.PropertiesToLoad.Add("memberOf")

$group = $search.FindOne()

# Check for Net_Supersol_New_Pharm group and update Scale and Scanner deviceName
if ($group -ne $null -and $group.Properties.memberof -like "*Net_Supersol_New_Pharm*") {
    # Update Scale
    $scaleNode = $xml.POSDevices.POSDeviceList.Scale
    if ($scaleNode.active -ne "false") {
        Write-Host "Net_Supersol_New_Pharm group detected, setting Scale to inactive..."
        $scaleNode.active = "false"
        $changesMade = $true
    } else {
        Write-Host "Scale is already set to inactive."
    }

    # Update Scanner deviceName to QS6000
    $scannerNode = $xml.POSDevices.POSDeviceList.Scanner
    if ($scannerNode.deviceName -ne "QS6000") {
        Write-Host "Updating Scanner deviceName to QS6000..."
        $scannerNode.deviceName = "QS6000"
        $changesMade = $true
    } else {
        Write-Host "Scanner deviceName is already set to QS6000."
    }
} elseif ($group -eq $null) {
    Write-Host "LDAP group not found or no members found."
}

# Save XML changes only if changes were made
if ($changesMade) {
    Write-Host "Saving changes to XML file..."
    $xml.Save($xmlPath)
    Write-Host "Done."
} else {
    Write-Host "No changes were made to XML file."
}

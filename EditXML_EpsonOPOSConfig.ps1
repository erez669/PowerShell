# Load XML content from file
Write-Host "Loading XML file..."
$xmlPath = "C:\retalix\wingpos\Files\Devices\EpsonOPOSConfig.xml"
$xml = [xml](Get-Content $xmlPath)

# Get EMV Node
Write-Host "Retrieving EMV settings..."
$emvNode = $xml.POSDevices.POSDeviceList.EMV
$oldEmvValue = $emvNode.active
Write-Host "Old EMV value: $oldEmvValue"

# Always set EMV to true
Write-Host "Setting EMV to true..."
$emvNode.active = "true"

# Reload the value
$emvNode = $xml.POSDevices.POSDeviceList.EMV
$newEmvValue = $emvNode.active
Write-Host "New EMV value after running is: $newEmvValue"

# Get physical device model using WMI
Write-Host "Fetching device model..."
$deviceModel = (Get-WmiObject Win32_ComputerSystemProduct).Name
Write-Host "Device Model: $deviceModel"

# Update LineDisplay for specific device models
$specialModels = @("4852E70", "4852570", "6200E35")
if ($specialModels -contains $deviceModel) {
    Write-Host "Special model detected, updating LineDisplay..."
    $lineDisplayNode = $xml.POSDevices.POSDeviceList.LineDisplay
    $lineDisplayNode.active = "false"
}

# LDAP group search
$computer = Get-WmiObject Win32_ComputerSystem
$branchNumber = $computer.Name.Split('-')[1]
$ldapPath = "LDAP://OU=Branch Groups,OU=Group Objects,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"
$groupCN = "Branch_$branchNumber"

$dirEntry = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
$search = New-Object System.DirectoryServices.DirectorySearcher($dirEntry)
$search.Filter = "(CN=$groupCN)"
$search.PropertiesToLoad.Add("memberOf")

$group = $search.FindOne()

# Update Scale if in Net_Supersol_New_Pharm
if ($group.Properties.memberof -like "*Net_Supersol_New_Pharm*") {
    $scaleNode = $xml.POSDevices.POSDeviceList.Scale
    $oldScaleValue = $scaleNode.active
    Write-Host "Old Scale value: $oldScaleValue"

    Write-Host "Net_Supersol_New_Pharm group detected, updating Scale value to false..."
    $scaleNode.active = "false"
    $scaleNode = $xml.POSDevices.POSDeviceList.Scale
    $newScaleValue = $scaleNode.active
    Write-Host "New Scale value after running is: $newScaleValue"
}

# Save XML changes
Write-Host "Saving changes to XML file..."
$xml.Save($xmlPath)
Write-Host "Done."

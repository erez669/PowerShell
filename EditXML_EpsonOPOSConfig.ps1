# Load XML content from file
$xmlPath = "C:\retalix\wingpos\Files\Devices\EpsonOPOSConfig.xml"
$xml = [xml](Get-Content $xmlPath)

# Default setting for EMV
$emvNode = $xml.POSDevices.POSDeviceList.EMV
$oldEmvValue = $emvNode.active

# Get physical device model using WMI
$deviceModel = (Get-WmiObject Win32_ComputerSystemProduct).Name

# Check condition for device models 4852E70 and 4852570
if ($deviceModel -eq "4852E70" -or $deviceModel -eq "4852570") {
    if ($oldEmvValue -eq "false") {
        Write-Host "EMV active attribute already set to false."
    } else {
        $emvNode.active = "false"
        Write-Host "EMV active attribute set to false for physical device model $deviceModel."
    }

    # Change LineDisplay to active="false"
    $lineDisplayNode = $xml.POSDevices.POSDeviceList.LineDisplay
    $oldLineDisplayValue = $lineDisplayNode.active

    if ($oldLineDisplayValue -eq "false") {
        Write-Host "LineDisplay active attribute already set to false."
    } else {
        $lineDisplayNode.active = "false"
        Write-Host "LineDisplay active attribute set to false for physical device model $deviceModel."
    }
} else {
    if ($oldEmvValue -eq "true") {
        Write-Host "EMV active attribute already set to true."
    } else {
        $emvNode.active = "true"
        Write-Host "EMV active attribute set to true."
    }

    Write-Host "No change was made to LineDisplay value."
}

# Save changes to the XML file
$xml.Save($xmlPath)
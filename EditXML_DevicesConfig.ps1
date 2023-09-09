$hostname = [System.Environment]::MachineName

if ($hostname -match "^POS-\d{3}-\d{2}-SCO$") {

  Write-Host "Debug: Matched POS-XYZ-XX-SCO hostname format detected, continue with script execution"

  if ((Get-WmiObject Win32_OperatingSystem).Version -like "6.1*") {
    $xmlPath = "C:\Program Files\Retalix\SCO.NET\App\DevicesConfig.xml" 
  } else {
    $xmlPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\DevicesConfig.xml"
  }

} elseif ($hostname -match "^POS-\d{3}-\d{2}-CSS$") {

  Write-Host "Debug: Matched POS-XYZ-XX-CSS hostname format detected, continue with script execution"
  
  $xmlPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\DevicesConfig.xml"

} else {

  Write-Host "Debug: Hostname format did not match, script execution was stopped"
  Exit 8

}

if ([string]::IsNullOrEmpty($xmlPath) -or -not (Test-Path $xmlPath)) {
    Write-Host "XML path is invalid or file does not exist. Exiting."
    Exit
}

# Load XML content from file
$xml = [xml](Get-Content $xmlPath)
Write-Host "XML loaded from: $xmlPath"

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

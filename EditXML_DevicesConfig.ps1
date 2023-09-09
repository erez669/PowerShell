$hostname = [System.Environment]::MachineName

if ($hostname -match "^POS-\w+-\w+-SCO$") {
    if ((Get-WmiObject Win32_OperatingSystem).Version -like "6.1*") {
        $xmlPath = "C:\Program Files\Retalix\SCO.NET\App\DevicesConfig.xml"  # Windows 7 x86
    } else {
        $xmlPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\DevicesConfig.xml"  # Windows 10 x64
    }
} elseif ($hostname -match "^POS-\w+-\w+-CSS$") {
    $xmlPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\DevicesConfig.xml"  # CSS always x64
} else {
    Write-Host "Hostname pattern didn't match. Exiting."
    Exit
}

if ([string]::IsNullOrEmpty($xmlPath) -or -not (Test-Path $xmlPath)) {
    Write-Host "XML path is invalid or file does not exist. Exiting."
    Exit
}

# Load XML content from file
$xml = [xml](Get-Content $xmlPath)

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

# Save changes to the XML file
$xml.Save($xmlPath)
Clear-Host

# Path to the output CSV
$outputCsv = "C:\temp\POS_Version.csv"

# Ensure the C:\temp directory exists
if (-not (Test-Path "C:\temp")) {
    New-Item -Path "C:\temp" -ItemType Directory -Force -Verbose
    Write-Host "C:\temp directory created."
}

# Check if the output CSV file exists and delete it
if (Test-Path $outputCsv) {
    Remove-Item $outputCsv -Force -Verbose
    Write-Host "Existing output file deleted."
}

# Load device names from a text file
$deviceNames = Get-Content "\\10.251.10.251\supergsrv\HdMatte\PowerShell\POSList.txt"

# Prepare an array to hold the output data
$results = @()

# Loop through each device name
foreach ($deviceName in $deviceNames) {
    Write-Host "`nProcessing device $deviceName"

    # Initialize the version variable
    $version = $null

    # Test the connection to the device first
    if (Test-Connection -ComputerName $deviceName -Count 1 -Quiet) {
        try {
            # Attempt to get the OS Architecture only for SCO or CSS devices
            if ($deviceName -like "*SCO" -or $deviceName -like "*CSS") {
                $osArchitecture = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $deviceName).OSArchitecture
                Write-Host "OS Architecture: $osArchitecture"
                $programFilesPath = if ($osArchitecture -eq "64-bit") { "\\$deviceName\C$\Program Files (x86)" } else { "\\$deviceName\C$\Program Files" }
                $fullPath = Join-Path $programFilesPath "Retalix\SCO.NET\App\SCO.exe"
            } else {
                $fullPath = "\\$deviceName\C$\retalix\wingpos\GroceryWinPos.exe"
            }

            # Check if the executable path exists and if so, get the version
            if (Test-Path $fullPath) {
                $fileVersionInfo = (Get-Item $fullPath).VersionInfo
                $version = $fileVersionInfo.ProductVersion
                Write-Host "Version found for $fullPath : $version"
            } else {
                $version = "Device is out of domain or path not found"
                Write-Host "Executable path not found: $fullPath"
            }
        } catch {
            Write-Host "Error occurred while processing $deviceName : $_"
            $version = "WMI error or inaccessible"
        }
    } else {
        $version = "Device not communicating"
        Write-Host "$deviceName is not communicating."
    }

    # Add the results for this device to the results array
    $obj = New-Object PSObject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name DeviceName -Value $deviceName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Version -Value $version
    
    $results += $obj
}

# Export results to CSV
if ($results.Count -gt 0) {
    $results | Export-Csv $outputCsv -NoTypeInformation -Verbose
    Write-Host "Data exported to $outputCsv"
} else {
    Write-Host "No data to export."
}

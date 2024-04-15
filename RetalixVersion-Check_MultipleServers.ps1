Clear-Host

# Path to the output CSV
$outputCsv = "C:\temp\Servers_Version.csv"

# Ensure the C:\temp directory exists
if (-not (Test-Path "C:\temp")) {
    New-Item -Path "C:\temp" -ItemType Directory -Force -Verbose
    Write-Output "C:\temp directory created."
}

# Check if the output CSV file exists and delete it
if (Test-Path $outputCsv) {
    Remove-Item $outputCsv
    Write-Output "Existing output file deleted."
}

# Load device names from a text file
$deviceNames = Get-Content "\\10.251.10.251\supergsrv\HdMatte\PowerShell\Servers.txt"

# Prepare an array to hold the output data
$results = @()

# Remote file path for version data
$remoteFilePath = "\D$\Retalix\FPStore\WSGpos\version.txt"

# Loop through each device name
foreach ($deviceName in $deviceNames) {
    Write-Output "Processing device $deviceName"

    # Construct the full path to the version file
    $fullPath = "\\$deviceName$remoteFilePath"

    # Test the connection to the device
    if (Test-Connection -ComputerName $deviceName -Count 1 -Quiet) {
        if (Test-Path $fullPath) {
            try {
                # Attempt to read the version from the file
                $versionContent = Get-Content $fullPath -ErrorAction Stop
                # Use regex to extract only the desired part of the version string
                $numericVersion = if ($versionContent -match '(\d[\d\._]*)') {$Matches[1]}
                if ($numericVersion) {
                    Write-Output "Numeric version extracted from $fullPath : $numericVersion"
                    $results += [PSCustomObject]@{
                        DeviceName = $deviceName
                        Version = $numericVersion
                    }
                } else {
                    Write-Output "No numeric version found in $fullPath"
                    $results += [PSCustomObject]@{
                        DeviceName = $deviceName
                        Version = "Version format not recognized"
                    }
                }
            } catch {
                Write-Output "Error reading from $fullPath : $_"
            }
        } else {
            Write-Output "Version file not found on $deviceName"
            $results += [PSCustomObject]@{
                DeviceName = $deviceName
                Version = "File not found"
            }
        }
    } else {
        Write-Output "No ping response from device $deviceName"
        $results += [PSCustomObject]@{
            DeviceName = $deviceName
            Version = "Device not communicating"
        }
    }
}

# Export results to CSV
if ($results.Count -gt 0) {
    $results | Export-Csv $outputCsv -NoTypeInformation
    Write-Output "Data exported to $outputCsv"
} else {
    Write-Output "No data to export."
}
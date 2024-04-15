Clear-Host

# Path to the output CSV
$outputCsv = "C:\temp\POS_Version.csv"

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
$deviceNames = Get-Content "\\10.251.10.251\supergsrv\HdMatte\PowerShell\POSList.txt"

# Prepare an array to hold the output data
$results = @()

# Define the paths for SCO based on architecture
$basePath64 = "\Program Files (x86)\Retalix\SCO.NET\App\SCO.exe"
$basePath86 = "\Program Files\Retalix\SCO.NET\App\SCO.exe"
$defaultPath = "\retalix\wingpos\GroceryWinPos.exe"

# Loop through each device name
foreach ($deviceName in $deviceNames) {
    Write-Output "Processing device $deviceName"

    # Test the connection to the device first
    if (Test-Connection -ComputerName $deviceName -Count 1 -Quiet) {
        $programFilesPath = "\\$deviceName\C`$\Program Files (x86)"
        $fullPath = $null

        if ($deviceName -like "*SCO") {
            if (Test-Path $programFilesPath) {
                $fullPath = "\\$deviceName\C`$$basePath64"
            } else {
                $fullPath = "\\$deviceName\C`$$basePath86"
            }
        } elseif ($deviceName -like "*CSS") {
            $fullPath = "\\$deviceName\C`$$basePath64"
        } else {
            $fullPath = "\\$deviceName\C`$$defaultPath"
        }

        if ($fullPath -and (Test-Path $fullPath)) {
            try {
                Write-Output "Checking version for $fullPath"
                $version = (Get-ItemProperty $fullPath -ErrorAction Stop).VersionInfo.ProductVersion
                if ($version) {
                    Write-Output "Version found for $fullPath : $version"
                    $results += [PSCustomObject]@{
                        DeviceName = $deviceName
                        Version = $version
                    }
                } else {
                    Write-Output "No version found for: $fullPath"
                }
            } catch {
                Write-Output "Error processing $fullPath : $_"
            }
        } else {
            Write-Output "Path could not be determined for $deviceName"
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

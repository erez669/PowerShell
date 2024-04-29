Clear-Host

# Ensure the C:\temp directory exists
$outputCsv = "C:\temp\POS_Version.csv"
if (-not (Test-Path "C:\temp")) {
    New-Item -Path "C:\temp" -ItemType Directory -Force -Verbose
    Write-Host "C:\temp directory created."
}

# Check if Excel is running and close it
$excelProcesses = Get-Process excel -ErrorAction SilentlyContinue
if ($excelProcesses) {
    $excelProcesses | Stop-Process -Force -Verbose
    Write-Host "Excel has been closed to release the lock on potential CSV files."
    Start-Sleep -Seconds 5  # Delay to allow the OS to release file locks
}

# Check if the output CSV file exists and delete it
if (Test-Path $outputCsv) {
    Remove-Item $outputCsv -Force -Verbose
    Write-Host "Existing output file deleted."
} else {
    Write-Host "No existing file to delete."
}

function Test-DeviceConnection($deviceName) {
    $maxRetries = 3
    for ($retryCount = 1; $retryCount -le $maxRetries; $retryCount++) {
        if (Test-Connection -ComputerName $deviceName -Count 1 -Quiet) {
            return $true
        } else {
            Write-Warning "$deviceName is not communicating. Retry $retryCount of $maxRetries."
            Start-Sleep -Seconds 2
        }
    }
    Write-Warning "Device $deviceName is not communicating after $maxRetries retries."
    return $false
}

function Get-ExecutablePath($deviceName) {
    if ($deviceName -like "*SCO") {
        try {
            $osArchitecture = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $deviceName -ErrorAction Stop).OSArchitecture
            Write-Host "OS Architecture: $osArchitecture"
            if ($osArchitecture -eq "64-bit") {
                return "\\$deviceName\C$\Program Files (x86)\Retalix\SCO.NET\App\SCO.exe"
            } else {
                return "\\$deviceName\C$\Program Files\Retalix\SCO.NET\App\SCO.exe"
            }
        } catch {
            Write-Warning "Error occurred while retrieving OS architecture for $deviceName : $_"
            return $null
        }
    } elseif ($deviceName -like "*CSS") {
        return "\\$deviceName\C$\Program Files (x86)\Retalix\SCO.NET\App\SCO.exe"
    } else {
        return "\\$deviceName\C$\retalix\wingpos\GroceryWinPos.exe"
    }
}

function Get-Version($deviceName, $programFilesPath) {
    $maxRetries = 3
    $retryCount = 0
    while ($retryCount -lt $maxRetries) {
        try {
            if (Test-Path $programFilesPath) {
                $fileVersionInfo = Get-Item $programFilesPath -ErrorAction Stop
                Write-Host "Successfully retrieved version for $deviceName"
                return $fileVersionInfo.VersionInfo.ProductVersion
            } else {
                Write-Warning "Path not found on device $deviceName. Retry attempt $retryCount of $maxRetries."
                $retryCount++
                Start-Sleep -Seconds (2 * $retryCount)  # Exponential back-off
            }
        } catch {
            Write-Warning "Attempt $retryCount : An error occurred while accessing $programFilesPath on $deviceName : $_"
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Start-Sleep -Seconds (2 * $retryCount)  # Exponential back-off
            }
        }
    }
    Write-Warning "Max 3 retries reached for $deviceName, no version found."
    return $null
}

# Load device names from a text file
$deviceNames = Get-Content "\\10.251.10.251\supergsrv\HdMatte\PowerShell\POSList.txt"

# Get the total count of devices
$totalDevices = $deviceNames.Count

# Display the total count
Write-Host "Total number of devices: $totalDevices"

# Use a generic list for better performance when collecting results
$results = New-Object System.Collections.Generic.List[psobject]

# Loop through each device name
foreach ($deviceName in $deviceNames) {
    Write-Host "`nProcessing device $deviceName"
    
    # Check the connection to the device and get the version
    if (Test-DeviceConnection $deviceName) {
        $programFilesPath = Get-ExecutablePath $deviceName
        if ($programFilesPath) {
            $version = Get-Version $deviceName $programFilesPath
            if ($null -eq $version) {
                Write-Warning "Version not found for $deviceName after 3 retries."
                $version = "Device might be out of domain or path not found"
            } else {
                Write-Host "Version found for $programFilesPath : $version"
            }
        } else {
            Write-Warning "Executable path not found for $deviceName."
            $version = "The specified network name is no longer available"
        }
    } else {
        Write-Warning "$deviceName is not communicating after 3 retries."
        $version = "Device is Not Communicating"
    }
    
    # Create a custom object for this device's result
    $obj = [PSCustomObject]@{
        DeviceName = $deviceName
        Version    = $version
    }
    
    # Append the result for this device to the CSV file in real-time
    $results.Add($obj) | Out-Null
}

# Export results to CSV
$results | Export-Csv $outputCsv -NoTypeInformation -Force
Write-Host "Data exported to $outputCsv"

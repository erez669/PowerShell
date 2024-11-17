Clear-Host

# Get the current computer name
$hostname = $env:COMPUTERNAME
Write-Output "Current hostname: $hostname"

if ($hostname -eq "WLPOSSRV888") {
    Write-Host "Hostname is WLPOSSRV888. Exiting script."
    exit 0
}

# Define the output path using the hostname
$outputPath = "\\hdsupport\PrintersBackup\${hostname}_printers.csv"
Write-Output "Output path: $outputPath"

try {
    # Remove existing CSV file if it exists
    if (Test-Path $outputPath) {
        Remove-Item -Path $outputPath -Force
        Write-Host "Existing CSV file removed."
    } else {
        Write-Host "No existing CSV file found."
    }

    # Get all printers
    $allPrinters = Get-Printer -ErrorAction Stop
    Write-Host "Total printers found: $($allPrinters.Count)"

    # Filter printers with IP address in PortName
    $ipPrinters = $allPrinters | Where-Object {
        $_.PortName -match '\d+\.\d+\.\d+\.\d+' -and
        $_.Name -notlike "*(redirected*"
    }
    Write-Host "IP-based printers found: $($ipPrinters.Count)"

    # Select required properties in the new order
    $printers = $ipPrinters | Select-Object Name, ShareName, PortName, DriverName

    Write-Host "`nPrinters to be exported:"
    $printers | Format-Table -AutoSize

    # Export to CSV
    $printers | Export-Csv -Path $outputPath -NoTypeInformation
    
    if (Test-Path $outputPath) {
        $fileSize = (Get-Item $outputPath).Length
        Write-Host "CSV file created. File size: $fileSize bytes"
        
        $content = Get-Content $outputPath
        Write-Host "CSV content preview (first 5 lines):"
        $content | Select-Object -First 5 | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "Warning: CSV file was not created."
    }

    Write-Host "IP-based printer list export process completed."
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    Write-Host "Error details: $($_.Exception.GetType().FullName)"
}

Write-Host "Script execution completed."
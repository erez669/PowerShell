# Script parameters
param
(
    [Parameter(Mandatory=$false)]
    [string]$ComputerListPath = "C:\Scripts\list.txt",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\Scripts\DiskSpaceReport.csv",

    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Scripts\DiskSpaceCheck.log"  # Added explicit log path parameter
)

# Function to write colored output with logging
function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [string]$Color = "White",
        [Parameter(Mandatory=$false)]
        [bool]$WriteHost = $true
    )
    
    try {
        # Get current timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Write to console if specified
        if ($WriteHost) {
            Write-Host "$timestamp - $Message" -ForegroundColor $Color
        }
        
        # Ensure log directory exists
        $logDir = Split-Path -Parent $LogPath
        if (-not (Test-Path -Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        # Write to log file with UTF8 encoding
        "$timestamp - $Message" | Out-File -FilePath $LogPath -Append -Force -Encoding UTF8
    }
    catch {
        # If logging fails, at least show it on console with the specific error
        Write-Host "$timestamp - $Message" -ForegroundColor $Color
        Write-Host "$timestamp - Error writing to log file: $_" -ForegroundColor Red
    }
}

# Function to validate input file
function Test-InputFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    try {
        Write-ColorOutput "Checking input file: $FilePath" "Yellow"
        
        if (-not (Test-Path -Path $FilePath)) {
            Write-ColorOutput "Error: Input file not found: $FilePath" "Red"
            return $false
        }
        
        $content = Get-Content -Path $FilePath -ErrorAction Stop
        if ($content.Count -eq 0) {
            Write-ColorOutput "Error: Input file is empty" "Red"
            return $false
        }
        
        Write-ColorOutput "Input file validation successful: Found $($content.Count) computer(s)" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Error validating input file: $_" "Red"
        return $false
    }
}

# Function to test computer connectivity
function Test-ComputerConnection {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        Write-ColorOutput "Testing connection to: $ComputerName" "Yellow"
        
        $ping = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
        if ($ping) {
            Write-ColorOutput "Successfully connected to $ComputerName" "Green"
            return $true
        }
        else {
            Write-ColorOutput "Failed to connect to $ComputerName" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "Error testing connection to $ComputerName`: $_" "Red"
        return $false
    }
}

# Function to get disk space information
function Get-DiskSpaceInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        Write-ColorOutput "Getting disk space information for: $ComputerName" "Yellow"
        
        # Get IP Address with error handling
        try {
            $ipAddress = [System.Net.Dns]::GetHostAddresses($ComputerName) | 
                        Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
                        Select-Object -ExpandProperty IPAddressToString -First 1
        }
        catch {
            Write-ColorOutput "Warning: Could not resolve IP for $ComputerName. Using empty value." "Yellow"
            $ipAddress = ""
        }
        
        # Get disk space information
        $disks = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ComputerName -Filter "DriveType=3" -ErrorAction Stop
        
        $results = @()
        foreach ($disk in $disks) {
            try {
                $freeSpaceGB = [math]::Round($disk.FreeSpace/1GB, 2)
                $totalSpaceGB = [math]::Round($disk.Size/1GB, 2)
                $usedSpaceGB = [math]::Round(($disk.Size - $disk.FreeSpace)/1GB, 2)
                $freeSpacePercent = [math]::Round(($disk.FreeSpace/$disk.Size) * 100, 2)
                
                $result = New-Object PSObject -Property @{
                    ComputerName = $ComputerName
                    IPAddress = $ipAddress
                    DriveLetter = $disk.DeviceID
                    TotalSpaceGB = $totalSpaceGB
                    UsedSpaceGB = $usedSpaceGB
                    FreeSpaceGB = $freeSpaceGB
                    FreeSpacePercent = $freeSpacePercent
                }
                
                $results += $result
                
                # Output colored status based on free space percentage
                $statusColor = if ($freeSpacePercent -lt 10) {
                    "Red"
                } elseif ($freeSpacePercent -lt 20) {
                    "Yellow"
                } else {
                    "Green"
                }
                
                Write-ColorOutput "Drive $($disk.DeviceID) - Free Space: $freeSpaceGB GB ($freeSpacePercent%)" $statusColor
            }
            catch {
                Write-ColorOutput "Error processing disk $($disk.DeviceID): $_" "Red"
            }
        }
        
        return $results
    }
    catch {
        Write-ColorOutput "Error getting disk space info for $ComputerName`: $_" "Red"
        return $null
    }
}

# Function to export results to CSV
function Export-ResultsToCsv {
    param(
        [Parameter(Mandatory=$true)]
        [Array]$Results,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    try {
        Write-ColorOutput "Exporting results to: $OutputPath" "Yellow"
        
        # Create directory if it doesn't exist
        $outputDir = Split-Path -Parent $OutputPath
        if (-not (Test-Path -Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        
        # Remove existing file if it exists
        if (Test-Path -Path $OutputPath) {
            Remove-Item -Path $OutputPath -Force
            Write-ColorOutput "Removed previous report file" "Yellow"
        }
        
        # Export to CSV with UTF8 encoding (creates new file)
        $Results | Export-Csv -Path $OutputPath -NoTypeInformation -Force -Encoding UTF8
        
        if (Test-Path -Path $OutputPath) {
            Write-ColorOutput "Results successfully exported to: $OutputPath" "Green"
            return $true
        }
        else {
            Write-ColorOutput "Error: Failed to create output file" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "Error exporting results: $_" "Red"
        return $false
    }
}

# Main script execution
try {
    Clear-Host
    
    # Remove existing log file if it exists and create new one
    if (Test-Path -Path $LogPath) {
        Remove-Item -Path $LogPath -Force
    }
    
    Write-ColorOutput "==================================================" "Yellow"
    Write-ColorOutput "Starting Disk Space Check Script" "Yellow"
    Write-ColorOutput "==================================================" "Yellow"
    Write-ColorOutput "Input File: $ComputerListPath" "Yellow"
    Write-ColorOutput "Output File: $OutputPath" "Yellow"
    Write-ColorOutput "Log File: $LogPath" "Yellow"
    Write-ColorOutput "==================================================" "Yellow"
    
    # Create Directories if they don't exist
    $scriptDir = Split-Path -Parent $ComputerListPath
    if (-not (Test-Path -Path $scriptDir)) {
        New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
    }
    
    # Validate input file
    if (-not (Test-InputFile -FilePath $ComputerListPath)) {
        exit 1
    }
    
    # Initialize results array
    $allResults = @()
    $computerCount = 0
    $successCount = 0
    $failureCount = 0
    
    # Process each computer
    foreach ($computer in Get-Content $ComputerListPath) {
        $computerCount++
        Write-ColorOutput "==================================================" "Yellow"
        Write-ColorOutput "Processing computer $computerCount`: $computer" "Yellow"
        
        if (Test-ComputerConnection -ComputerName $computer) {
            $diskInfo = Get-DiskSpaceInfo -ComputerName $computer
            if ($diskInfo) {
                $allResults += $diskInfo
                $successCount++
            }
            else {
                $failureCount++
                Write-ColorOutput "Failed to get disk info for: $computer" "Red"
            }
        }
        else {
            $failureCount++
        }
    }
    
    # Export results if we have any
    if ($allResults.Count -gt 0) {
        Export-ResultsToCsv -Results $allResults -OutputPath $OutputPath
    }
    else {
        Write-ColorOutput "No results to export!" "Red"
        exit 2
    }
    
    # Display summary
    Write-ColorOutput "==================================================" "Yellow"
    Write-ColorOutput "Script Execution Summary" "Yellow"
    Write-ColorOutput "==================================================" "Yellow"
    Write-ColorOutput "Total Computers Processed: $computerCount" "White"
    Write-ColorOutput "Successful: $successCount" "Green"
    Write-ColorOutput "Failed: $failureCount" "Red"
    Write-ColorOutput "==================================================" "Yellow"
    
    if ($failureCount -eq 0) {
        Write-ColorOutput "Script completed successfully!" "Green"
        exit 0
    }
    else {
        Write-ColorOutput "Script completed with some failures. Check the log file for details." "Yellow"
        exit 3
    }
}
catch {
    Write-ColorOutput "==================================================" "Red"
    Write-ColorOutput "Unhandled error occurred: $_" "Red"
    Write-ColorOutput $_.ScriptStackTrace "Red"
    Write-ColorOutput "==================================================" "Red"
    exit 4
}
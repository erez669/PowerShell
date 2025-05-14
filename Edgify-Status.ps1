# Enhanced PowerShell script to detect Edgify Active status from DevicesConfig.xml
# Compatible with PowerShell v2 and higher - with robust multi-device CSV append

# Function for colored output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Function for section headers
function Write-SectionHeader {
    param([string]$Title)
    
    Write-Host "`n=============================================" -ForegroundColor Cyan
    Write-Host "   $Title" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
}

# Function to append to CSV with improved concurrency handling - PowerShell v2 compatible
function Export-ToCsvRobust {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    # Create a temporary file with unique name based on hostname and timestamp
    $hostname = $env:COMPUTERNAME
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $randomPart = Get-Random -Minimum 1000 -Maximum 9999
    $tempDir = [System.IO.Path]::GetTempPath()
    $tempFile = Join-Path -Path $tempDir -ChildPath "EdgifyStatus_${hostname}_${timestamp}_${randomPart}.csv"
    
    Write-ColorOutput "Creating temporary CSV file: $tempFile" "Yellow"
    
    try {
        # Export data to the temporary file
        $Data | Export-Csv -Path $tempFile -NoTypeInformation -Force
        
        # Create parent directory if it doesn't exist
        $parentDir = Split-Path -Path $Path -Parent
        if (-not (Test-Path -Path $parentDir)) {
            Write-ColorOutput "Creating directory: $parentDir" "Yellow"
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        }
        
        # Now try to append this to the target file with retries for concurrency
        $maxRetries = 10
        $delay = 500 # Start with 500ms delay
        $retry = 0
        $success = $false
        
        while (-not $success -and $retry -lt $maxRetries) {
            try {
                $retry++
                
                # Check if the target CSV exists
                if (Test-Path -Path $Path) {
                    Write-ColorOutput "Attempt $retry : Target CSV exists, appending data..." "Yellow"
                    
                    # Read our temporary file content (skip header if appending)
                    $tempContent = Get-Content -Path $tempFile | Select-Object -Skip 1
                    
                    # Use PowerShell v2 compatible method to append (using StreamWriter)
                    $fileStream = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
                    $streamWriter = New-Object System.IO.StreamWriter($fileStream)
                    
                    try {
                        foreach ($line in $tempContent) {
                            $streamWriter.WriteLine($line)
                        }
                        $streamWriter.Flush()
                    } 
                    finally {
                        # Make sure we close the stream even if there's an error
                        if ($streamWriter) { $streamWriter.Close() }
                        if ($fileStream) { $fileStream.Close() }
                    }
                } 
                else {
                    Write-ColorOutput "Attempt $retry : Target CSV doesn't exist, creating new file..." "Yellow"
                    
                    # Just copy our temp file to the destination
                    Copy-Item -Path $tempFile -Destination $Path -Force
                }
                
                $success = $true
                Write-ColorOutput "Successfully wrote to CSV file" "Green"
            }
            catch {
                Write-ColorOutput "Attempt $retry failed: $_" "Red"
                
                if ($retry -lt $maxRetries) {
                    Write-ColorOutput "Waiting $delay ms before retry..." "Yellow"
                    Start-Sleep -Milliseconds $delay
                    # Exponential backoff with jitter
                    $delay = [int]($delay * 1.5 + (Get-Random -Minimum 1 -Maximum 100))
                }
                else {
                    Write-ColorOutput "Maximum retries reached. Saving data to local backup file." "Red"
                    
                    # Create local backup as last resort
                    $backupFile = "C:\EdgifyStatus_${hostname}_${timestamp}.csv"
                    Copy-Item -Path $tempFile -Destination $backupFile -Force
                    Write-ColorOutput "Data saved to backup file: $backupFile" "Yellow"
                    throw "Failed to write to network CSV after $maxRetries attempts. Local backup created."
                }
            }
        }
    }
    finally {
        # Clean up the temp file
        if (Test-Path -Path $tempFile) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# Start script
Clear-Host
Write-SectionHeader "EDGIFY DEVICE STATUS DETECTOR"

Write-ColorOutput "Starting script execution..." "Green"
Write-ColorOutput "Current user: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" "Yellow"
Write-ColorOutput "Current computer: $env:COMPUTERNAME" "Yellow"
Write-ColorOutput "Current date/time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Yellow"

# Get PowerShell version information
$psVersion = $PSVersionTable.PSVersion.Major
Write-ColorOutput "PowerShell Version: $psVersion" "Yellow"

# Get OS information
$osInfo = $null
try {
    Write-ColorOutput "Getting OS information..." "Yellow"
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
    $osCaption = $osInfo.Caption
    $osVersion = $osInfo.Version
    $osArchitecture = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    
    Write-ColorOutput "OS: $osCaption ($osVersion)" "Yellow"
    Write-ColorOutput "OS Architecture: $osArchitecture" "Yellow"
}
catch {
    Write-ColorOutput "WARNING: Unable to retrieve detailed OS information: $_" "Yellow"
    $osCaption = "Unknown"
    $osVersion = "Unknown"
    $osArchitecture = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    Write-ColorOutput "OS Architecture: $osArchitecture" "Yellow"
}

Write-SectionHeader "FILE DETECTION"

# Define the correct path based on architecture
if ($osArchitecture -eq "x64") {
    $xmlPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\DevicesConfig.xml"
    Write-ColorOutput "Using x64 architecture path: $xmlPath" "Yellow"
} else {
    $xmlPath = "C:\Program Files\Retalix\SCO.NET\App\DevicesConfig.xml"
    Write-ColorOutput "Using x86 architecture path: $xmlPath" "Yellow"
}

# Check if the path exists
if (-not (Test-Path -Path $xmlPath -ErrorAction SilentlyContinue)) {
    Write-ColorOutput "ERROR: DevicesConfig.xml not found at: $xmlPath" "Red"
    Write-ColorOutput "Please verify the file location manually and update the script." "Red"
    exit 1
} else {
    Write-ColorOutput "FOUND DevicesConfig.xml at: $xmlPath" "Green"
}

# Define the output CSV path (network location)
$csvPath = "\\myserver\POS\Edgify_DeviceStatus.csv"

# Get the hostname of the current device
$hostname = $env:COMPUTERNAME

Write-SectionHeader "XML PARSING"

# Load the XML file and export device statuses
try {
    Write-ColorOutput "Reading XML file: $xmlPath" "Yellow"
    
    # PS v2 compatible way to read the file
    $fileContent = [String]::Join("`r`n", (Get-Content -Path $xmlPath -ErrorAction Stop))
    
    if ([String]::IsNullOrEmpty($fileContent)) {
        Write-ColorOutput "ERROR: XML file is empty!" "Red"
        exit 1
    }
    
    Write-ColorOutput "File content loaded ($(($fileContent.Length)) bytes)" "Green"
    
    # Parse the XML content - PS v2 compatible way
    try {
        $xmlContent = New-Object System.Xml.XmlDocument
        $xmlContent.LoadXml($fileContent)
        Write-ColorOutput "Successfully parsed XML structure" "Green"
        
        # Display root elements
        Write-ColorOutput "XML root element: $($xmlContent.DocumentElement.Name)" "Yellow"
        
        # Count child nodes (PS v2 compatible)
        $deviceNodes = @($xmlContent.Devices.ChildNodes | Where-Object { $_.NodeType -eq "Element" })
        $deviceCount = $deviceNodes.Count
        Write-ColorOutput "Found $deviceCount device nodes in the XML" "Yellow"
    }
    catch {
        Write-ColorOutput "ERROR: Failed to parse XML: $_" "Red"
        Write-ColorOutput "First 100 characters of file: $($fileContent.Substring(0, [Math]::Min(100, $fileContent.Length)))" "Gray"
        exit 1
    }
    
    $results = @()
    $edgifyFound = $false
    
    # Process each device node
    Write-ColorOutput "Processing device nodes:" "Yellow"
    foreach ($node in $deviceNodes) {
        $deviceType = $node.GetAttribute("DeviceType")
        $active = $node.GetAttribute("Active")
        
        Write-ColorOutput "  Device Type: $deviceType, Active: $active" "Gray"
        
        # Check if this is an Edgify device
        if ($deviceType -eq "EdgifyVideoRecognition") {
            Write-ColorOutput "    EDGIFY DEVICE FOUND!" "Green"
            $edgifyFound = $true
            
            $deviceObj = New-Object PSObject
            $deviceObj | Add-Member -MemberType NoteProperty -Name "Hostname" -Value $hostname
            $deviceObj | Add-Member -MemberType NoteProperty -Name "OSCaption" -Value $osCaption
            $deviceObj | Add-Member -MemberType NoteProperty -Name "OSArchitecture" -Value $osArchitecture
            # DeviceName removed as requested
            $deviceObj | Add-Member -MemberType NoteProperty -Name "DeviceType" -Value $deviceType
            $deviceObj | Add-Member -MemberType NoteProperty -Name "Active" -Value $active
            $deviceObj | Add-Member -MemberType NoteProperty -Name "Connection" -Value $node.GetAttribute("Connection")
            $deviceObj | Add-Member -MemberType NoteProperty -Name "Port" -Value $node.GetAttribute("Port")
            $deviceObj | Add-Member -MemberType NoteProperty -Name "TimeChecked" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            
            $results += $deviceObj
        }
    }
    
    if ($results.Count -eq 0) {
        Write-ColorOutput "No Edgify devices found in the XML file. Adding entry with status 'Not Configured'" "Yellow"
        $deviceObj = New-Object PSObject
        $deviceObj | Add-Member -MemberType NoteProperty -Name "Hostname" -Value $hostname
        $deviceObj | Add-Member -MemberType NoteProperty -Name "OSCaption" -Value $osCaption
        $deviceObj | Add-Member -MemberType NoteProperty -Name "OSArchitecture" -Value $osArchitecture
        # DeviceName removed as requested
        $deviceObj | Add-Member -MemberType NoteProperty -Name "DeviceType" -Value "Not Configured"
        $deviceObj | Add-Member -MemberType NoteProperty -Name "Active" -Value "false"
        $deviceObj | Add-Member -MemberType NoteProperty -Name "Connection" -Value ""
        $deviceObj | Add-Member -MemberType NoteProperty -Name "Port" -Value ""
        $deviceObj | Add-Member -MemberType NoteProperty -Name "TimeChecked" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        
        $results += $deviceObj
    }
    
    Write-SectionHeader "CSV EXPORT"
    
    Write-ColorOutput "CSV destination: $csvPath" "Yellow"
    
    # Use the robust CSV export function
    try {
        Export-ToCsvRobust -Data $results -Path $csvPath
    }
    catch {
        Write-ColorOutput "WARNING: $($_)" "Red"
    }
    
    Write-SectionHeader "SUMMARY"
    
    Write-ColorOutput "OPERATION SUCCESSFUL" "Green"
    Write-ColorOutput "Hostname: $hostname" "White"
    Write-ColorOutput "OS: $osCaption" "White"
    Write-ColorOutput "OS Architecture: $osArchitecture" "White"
    Write-ColorOutput "XML Path: $xmlPath" "White"
    Write-ColorOutput "CSV Path: $csvPath" "White"
    Write-ColorOutput "Devices Exported: $($results.Count)" "White"
    
    $activeCount = ($results | Where-Object { $_.Active -eq "true" }).Count
    $inactiveCount = ($results | Where-Object { $_.Active -eq "false" }).Count
    
    Write-ColorOutput "Active devices: $activeCount" "Green"
    Write-ColorOutput "Inactive devices: $inactiveCount" "Red"
    
    # For each exported device, show detailed status
    Write-ColorOutput "Device Status Details:" "Yellow"
    foreach ($device in $results) {
        $statusColor = if ($device.Active -eq "true") { "Green" } else { "Red" }
        $statusText = if ($device.Active -eq "true") { "ACTIVE" } else { "INACTIVE" }
        Write-ColorOutput "  - $($device.DeviceType): $statusText" $statusColor
    }
    
    Write-ColorOutput "Execution completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Yellow"
} 
catch {
    Write-SectionHeader "ERROR"
    Write-ColorOutput "Fatal error processing XML: $_" "Red"
    Write-ColorOutput "Error details: $($_.Exception.Message)" "Red"
    
    # PS v2 doesn't have ScriptStackTrace property
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Gray"
    }
    
    exit 1
}

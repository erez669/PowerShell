# Script parameters
param
(
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "\\10.250.236.25\IvantiShare\PackagesMarlogMifalim\MicroStrategy_2024",

    [Parameter(Mandatory=$false)]
    [decimal]$MinimumFreeSpaceGB = 20,

    [Parameter(Mandatory=$false)]
    [string]$InstallFolderName = "MicroStrategy_2024",

    [Parameter(Mandatory=$false)]
    [string]$ResponseFilePath = "Installations\response_custom_m11_4_09.ini"
)

Clear-Host

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
        # Create path for log file in installation directory
        $logPath = "C:\Install\MicroStrategy_2024\installationlog.log"
        $logDir = "C:\Install\MicroStrategy_2024"
        
        # Create directory if it doesn't exist
        if (-not (Test-Path -Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        # Write to console if specified
        if ($WriteHost) {
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" -ForegroundColor $Color
        }
        
        # Write to log file
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" | Out-File -FilePath $logPath -Append
    }
    catch {
        # If logging fails, at least show it on console
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" -ForegroundColor $Color
        Write-Host "Warning: Could not write to log file: $_" -ForegroundColor Yellow
    }
}

# Check for administrator rights
function Test-AdminRights {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-ColorOutput "Script requires Administrator privileges!" "Red"
        Write-ColorOutput "Attempting to elevate privileges..." "Yellow"
        try {
            $arguments = "& '" + $myinvocation.mycommand.definition + "'"
            Start-Process powershell -Verb runAs -ArgumentList $arguments
            return $false
        }
        catch {
            Write-ColorOutput "Failed to elevate privileges: $_" "Red"
            return $false
        }
    }
    Write-ColorOutput "Running with Administrator privileges" "Green"
    return $true
}

# Function to verify network path accessibility
function Test-NetworkPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    Write-ColorOutput "Testing network path accessibility: $Path" "Yellow"
    
    if (Test-Path -Path $Path) {
        Write-ColorOutput "Network path is accessible" "Green"
        return $true
    } else {
        Write-ColorOutput "Error: Cannot access network path: $Path" "Red"
        Write-ColorOutput "Please verify network connectivity and permissions" "Red"
        return $false
    }
}

# Function to check disk space
function Get-AvailableDisk {
    param(
        [Parameter(Mandatory=$true)]
        [decimal]$RequiredSpaceGB
    )
    
    Write-ColorOutput "Checking available disk space on all drives..." "Yellow"
    
    # Get all fixed drives
    $drives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    $availableDrives = @()
    
    foreach ($drive in $drives) {
        $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        $totalSpaceGB = [math]::Round($drive.Size / 1GB, 2)
        
        Write-ColorOutput "Checking drive $($drive.DeviceID):" "Yellow"
        Write-ColorOutput "  Total Space: $totalSpaceGB GB" "Yellow"
        Write-ColorOutput "  Free Space: $freeSpaceGB GB" "Yellow"
        Write-ColorOutput "  Required Space: $RequiredSpaceGB GB" "Yellow"
        
        if ($freeSpaceGB -ge $RequiredSpaceGB) {
            Write-ColorOutput "  Status: SUFFICIENT SPACE" "Green"
            $availableDrives += $drive
        } else {
            Write-ColorOutput "  Status: INSUFFICIENT SPACE" "Red"
        }
    }
    
    # Return the first available drive or $null if none found
    return $availableDrives | Select-Object -First 1
}

# Function to copy installation files with existence check and progress bar
function Copy-InstallationFiles {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        [Parameter(Mandatory=$true)]
        [string]$DestinationDrive,
        [Parameter(Mandatory=$true)]
        [string]$InstallFolderName
    )
    
    try {
        # Create full destination path
        $destinationPath = Join-Path -Path $DestinationDrive -ChildPath "Install\$InstallFolderName"
        
        Write-ColorOutput "Checking destination path: $destinationPath" "Yellow"

        # Check if destination exists and has setup files
        $setupExe = Join-Path -Path $destinationPath -ChildPath "Installations\Setup.exe"
        $responseFile = Join-Path -Path $destinationPath -ChildPath "Installations\response_custom_m11_4_09.ini"

        if ((Test-Path $setupExe) -and (Test-Path $responseFile)) {
            Write-ColorOutput "Installation files already exist at destination!" "Green"
            
            # Get source and destination file counts and sizes for verification
            $sourceFiles = Get-ChildItem -Path $SourcePath -Recurse
            $destFiles = Get-ChildItem -Path $destinationPath -Recurse
            
            $sourceCount = ($sourceFiles | Measure-Object).Count
            $destCount = ($destFiles | Measure-Object).Count
            
            $sourceSize = ($sourceFiles | Measure-Object -Property Length -Sum).Sum
            $destSize = ($destFiles | Measure-Object -Property Length -Sum).Sum
            
            Write-ColorOutput "Source files: $sourceCount (Size: $([math]::Round($sourceSize/1GB, 2)) GB)" "Yellow"
            Write-ColorOutput "Destination files: $destCount (Size: $([math]::Round($destSize/1GB, 2)) GB)" "Yellow"
            
            if (($sourceCount -eq $destCount) -and ($sourceSize -eq $destSize)) {
                Write-ColorOutput "File counts and sizes match - using existing files" "Green"
                return $destinationPath
            } else {
                Write-ColorOutput "File count or size mismatch - will perform fresh copy" "Yellow"
            }
        }
        
        # Create destination directory if it doesn't exist
        if (-not (Test-Path $destinationPath)) {
            Write-ColorOutput "Creating destination directory: $destinationPath" "Yellow"
            New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        }
        
        Write-ColorOutput "Starting file copy operation:" "Yellow"
        Write-ColorOutput "  From: $SourcePath" "Yellow"
        Write-ColorOutput "  To: $destinationPath" "Yellow"
        
        # First, get total size of files to copy for progress calculation
        $totalSize = (Get-ChildItem $SourcePath -Recurse | Measure-Object -Property Length -Sum).Sum
        Write-ColorOutput "Total size to copy: $([math]::Round($totalSize/1GB, 2)) GB" "Yellow"
        
        # Define log file paths
        $robocopyLogPath = Join-Path -Path $destinationPath -ChildPath "robocopy.log"
        
        # Copy files with progress using robocopy
        $robocopyArgs = @(
            $SourcePath,
            $destinationPath,
            "/E",        # Copy subdirectories, including empty ones
            "/R:3",      # Number of retries
            "/W:7",      # Wait time between retries
            "/MT:8",     # Multi-threaded copying
            "/NS",       # No file size
            "/NC",       # No file class
            "/NFL",      # No file list
            "/NDL",      # No directory list
            "/NP",       # No progress
            "/LOG:$robocopyLogPath"  # Log file in destination directory
        )
        
        Write-ColorOutput "Starting robocopy operation..." "Yellow"
        
        # Start robocopy as background job
        $robocopyProcess = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -NoNewWindow -PassThru
        
        # Monitor progress while robocopy is running
        $completed = 0
        $lastCompleted = 0
        while (!$robocopyProcess.HasExited) {
            Start-Sleep -Milliseconds 500
            
            $copiedSize = (Get-ChildItem $destinationPath -Recurse | Measure-Object -Property Length -Sum).Sum
            if ($copiedSize -gt 0 -and $totalSize -gt 0) {
                $completed = [math]::Round(($copiedSize / $totalSize) * 100, 0)
                $copiedGB = [math]::Round($copiedSize/1GB, 2)
                $totalGB = [math]::Round($totalSize/1GB, 2)
                if ($completed -gt $lastCompleted) {
                    Write-Progress -Activity "Copying Files" -Status "$completed% Complete ($copiedGB GB of $totalGB GB)" -PercentComplete $completed
                    $lastCompleted = $completed
                }
            }
        }
        
        # Clear the progress bar
        Write-Progress -Activity "Copying Files" -Completed
        
        # Check robocopy exit code (0-7 are success codes)
        if ($robocopyProcess.ExitCode -lt 8) {
            Write-ColorOutput "Files copied successfully to $destinationPath!" "Green"
            Write-ColorOutput "Copy operation completed: 100%" "Green"
            return $destinationPath
        } else {
            Write-ColorOutput "Error copying files. Robocopy exit code: $($robocopyProcess.ExitCode)" "Red"
            return $null
        }
    }
    catch {
        Write-ColorOutput "Error during file copy: $_" "Red"
        return $null
    }
}

# Function to stop MicroStrategy processes
function Stop-MicroStrategyProcesses {
    $processes = @("MSTRDesk")
    
    foreach ($process in $processes) {
        Write-ColorOutput "Attempting to stop $process process..." "Yellow"
        Get-Process -Name $process -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $_ | Stop-Process -Force
                Write-ColorOutput "Successfully stopped $process (PID: $($_.Id))" "Green"
                Start-Sleep -Seconds 2  # Give process time to fully terminate
            }
            catch {
                Write-ColorOutput "Warning: Could not stop $process process: $_" "Yellow"
            }
        }
    }
}

# Function to run installation
function Start-MicroStrategyInstallation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstallPath,
        [Parameter(Mandatory=$true)]
        [string]$ResponseFilePath
    )
    
    try {
        $setupPath = Join-Path -Path $InstallPath -ChildPath "Installations\Setup.exe"
        $fullResponsePath = Join-Path -Path $InstallPath -ChildPath $ResponseFilePath
        
        Write-ColorOutput "Verifying installation files:" "Yellow"
        Write-ColorOutput "  Setup.exe path: $setupPath" "Yellow"
        Write-ColorOutput "  Response file path: $fullResponsePath" "Yellow"
        
        if (-not (Test-Path $setupPath)) {
            Write-ColorOutput "Error: Setup.exe not found at path: $setupPath" "Red"
            return $false
        }
        
        if (-not (Test-Path $fullResponsePath)) {
            Write-ColorOutput "Error: Response file not found at path: $fullResponsePath" "Red"
            return $false
        }
        
        Write-ColorOutput "Starting MicroStrategy installation..." "Yellow"
        
        $installArgs = @(
            "-L0009",
            "--ResponseFile=`"$fullResponsePath`""
        )
        
        Write-ColorOutput "Installation command:" "Yellow"
        Write-ColorOutput "  $setupPath $($installArgs -join ' ')" "Yellow"
        
        $installProcess = Start-Process -FilePath $setupPath -ArgumentList $installArgs -NoNewWindow -Wait -PassThru
        
        # Modified this part to consider both 0 and 3010 as success codes
        if ($installProcess.ExitCode -eq 0 -or $installProcess.ExitCode -eq 3010) {
            Write-ColorOutput "Installation completed successfully!" "Green"
            if ($installProcess.ExitCode -eq 3010) {
                Write-ColorOutput "Exit code 3010: Installation successful, reboot required." "Yellow"
            }
            return $true
        } else {
            Write-ColorOutput "Installation failed with exit code: $($installProcess.ExitCode)" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "Error during installation: $_" "Red"
        return $false
    }
}

# Main script execution
try {
    Clear-Host
    Write-ColorOutput "==================================================" "Yellow"
    Write-ColorOutput "Starting MicroStrategy Installation Script" "Yellow"
    Write-ColorOutput "==================================================" "Yellow"

    # Check for admin rights first
    if (-not (Test-AdminRights)) {
        exit 1
    }
    
    Write-ColorOutput "Source Path: $SourcePath" "Yellow"
    Write-ColorOutput "Minimum Required Space: $MinimumFreeSpaceGB GB" "Yellow"
    Write-ColorOutput "Installation Folder: $InstallFolderName" "Yellow"
    Write-ColorOutput "==================================================" "Yellow"
    
    # First, verify network path accessibility
    if (-not (Test-NetworkPath -Path $SourcePath)) {
        Write-ColorOutput "Cannot proceed - source path is not accessible" "Red"
        exit 5
    }
    
    # Check for available disk
    $targetDisk = Get-AvailableDisk -RequiredSpaceGB $MinimumFreeSpaceGB
    
    if (-not $targetDisk) {
        Write-ColorOutput "No disk with sufficient free space ($MinimumFreeSpaceGB GB) found!" "Red"
        exit 17
    }
    
    Write-ColorOutput "Selected target disk: $($targetDisk.DeviceID)" "Green"
    
    # Stop MicroStrategy processes
    Stop-MicroStrategyProcesses
    
    # Copy files
    $installPath = Copy-InstallationFiles -SourcePath $SourcePath -DestinationDrive $targetDisk.DeviceID -InstallFolderName $InstallFolderName
    
    if (-not $installPath) {
        Write-ColorOutput "Failed to copy installation files!" "Red"
        exit 17
    }
    
    # Run installation
    $installSuccess = Start-MicroStrategyInstallation -InstallPath $installPath -ResponseFilePath $ResponseFilePath
    
    if (-not $installSuccess) {
        Write-ColorOutput "Installation failed!" "Red"
        exit 4
    }
    
    Write-ColorOutput "==================================================" "Green"
    Write-ColorOutput "Script completed successfully!" "Green"
    Write-ColorOutput "Installation location: $installPath" "Green"
    Write-ColorOutput "==================================================" "Green"
    exit 0
}
catch {
    Write-ColorOutput "==================================================" "Red"
    Write-ColorOutput "Unhandled error occurred: $_" "Red"
    Write-ColorOutput $_.ScriptStackTrace "Red"
    Write-ColorOutput "==================================================" "Red"
    exit 4
}

Clear-Host

# Main script: Witness888-CopyFolders.ps1

# Define source and destination paths
$networkPath = "\\wlpossrv888\IvantiShare"
$destPath = "D:\IvantiShare"

# Define folders to process
$folders = @(
    "drivers\888",  # Specific subfolder in drivers
    "images",
    "packages"
)

# Define exclusion list - folders to skip
$excludedFolders = @(
    "LDHashDir",
    "Win7x64ENT",
    "Win7x86PRO_Clean",
    "W2k12_x64",
    "W2K19x64",
    "Win10LTSC2019"
)

# Function to write messages to console
function Write-Message {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "$timestamp - [$Type] $Message"
}

try {
    Write-Message "Script started. Setting up network access..."
    
    # Try to access the network path directly first
    if (Test-Path $networkPath) {
        Write-Message "Network path is already accessible"
        $sourcePath = $networkPath
    }
    else {
        Write-Message "Need to establish network connection. Loading credentials..."
        
        # Load credentials (same as first script)
        $KeyBytes = [System.IO.File]::ReadAllBytes("$PSScriptRoot\encryption.key")
        $CredentialContent = [System.IO.File]::ReadAllText("$PSScriptRoot\credentials.key")
        $credParts = $CredentialContent.Split('|')
        $Username = $credParts[0]
        $EncryptedPassword = $credParts[1]
        $SecurePassword = $EncryptedPassword | ConvertTo-SecureString -Key $KeyBytes
        $Credential = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)

        # Find available drive letter
        $UsedDrives = Get-WmiObject Win32_LogicalDisk | 
            Select-Object -ExpandProperty DeviceID | 
            ForEach-Object { $_.Replace(":", "") }
        $DriveLetter = [char[]](67..90) | 
            Where-Object { $_ -notin $UsedDrives } | 
            Select-Object -First 1

        # Map network drive
        Write-Message "Mapping network drive to $DriveLetter..."
        New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $networkPath -Credential $Credential -Persist | Out-Null
        $sourcePath = "${DriveLetter}:"
    }

    # Create destination folder if needed
    if (!(Test-Path -Path $destPath)) {
        Write-Message "Creating destination folder: $destPath"
        New-Item -ItemType Directory -Path $destPath -Force | Out-Null
    }

    # Share destination folder if needed
    $shareName = "IvantiShare"
    if (!(Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue)) {
        Write-Message "Creating SMB share: $shareName"
        New-SmbShare -Name $shareName -Path $destPath -FullAccess "Everyone" | Out-Null
    }

    # Process each folder
    foreach ($folder in $folders) {
        $sourceFolder = Join-Path $sourcePath $folder
        $destFolder = Join-Path $destPath $folder
        
        Write-Message "Processing folder: $folder"
        if (!(Test-Path -Path $destFolder)) {
            New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
        }

        # Build robocopy arguments
        $roboArgs = @(
            $sourceFolder
            $destFolder
            "/E"           # Copy subdirectories
            "/R:3"         # Retries
            "/W:5"         # Wait time
            "/MT:8"        # Multi-threaded
            "/NFL"         # No file list
            "/NDL"         # No directory list
        )

        # Add exclusions
        foreach ($excludedFolder in $excludedFolders) {
            $roboArgs += "/XD"
            $roboArgs += "*$excludedFolder*"
        }

        # Execute robocopy
        Write-Message "Starting copy for $folder"
        $result = Start-Process -FilePath "robocopy.exe" -ArgumentList $roboArgs -NoNewWindow -Wait -PassThru

        # Check result
        switch ($result.ExitCode) {
            0 { Write-Message "No files copied for $folder" }
            1 { Write-Message "Files copied successfully for $folder" }
            2 { Write-Message "Extra files or directories detected for $folder" }
            4 { Write-Message "Some mismatched files or directories for $folder" }
            8 { Write-Message "Some files or directories could not be copied for $folder" -Type "WARNING" }
            16 { Write-Message "Serious error occurred for $folder" -Type "ERROR" }
            default { Write-Message "Unknown exit code $($result.ExitCode) for $folder" -Type "WARNING" }
        }
    }

    Write-Message "All folders processed"
}
catch {
    Write-Message "Error occurred: $($_.Exception.Message)" -Type "ERROR"
    exit 1
}

Write-Message "Script completed successfully"
exit 0
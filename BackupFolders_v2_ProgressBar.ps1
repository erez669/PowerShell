# Define the path for local backup files
$localFiles = "C:\yarpadb\sql_Backup"

# Initialize an array to hold files to be copied
$filesToCopy = @()

# Get a list of all subdirectories containing backup files
$backupFolders = Get-ChildItem -Path $localFiles -Recurse -Verbose | Where-Object { $_.PSIsContainer }

Write-Output "Local files path: $localFiles"

# Extract the appropriate number from the hostname
if ($env:COMPUTERNAME -match 'WKS-(\d+)-\d{3}') {
    $serverNum = $Matches[1]
} elseif ($env:COMPUTERNAME -match '\d{3}$') {
    $serverNum = $Matches[0]
} else {
    Write-Host "The hostname does not match expected patterns."
    exit
}

Write-Host "Server number detected: $serverNum"

# Find the latest .bak file in each subdirectory
foreach ($folder in $backupFolders) {
    Write-Host "Looking in folder: $($folder.FullName)"
    
    $latestBackup = Get-ChildItem -Path $folder.FullName -Filter *.bak |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestBackup) {
        Write-Host "Latest backup: $($latestBackup.FullName)"
        $filesToCopy += $latestBackup
    }
}

Write-Host "Files to be copied:"
$filesToCopy | ForEach-Object { Write-Host $_.FullName }

# Define the remote paths
$remotePathPL = "\\PLPOSSRV$serverNum\E$\YarpaBackup_$serverNum"
$remotePathWKS = "\\WKS-$serverNum-102\C$\YarpaBackup_$serverNum"

# Function to copy files with progress
function Copy-WithProgress($source, $destination, $filesToCopy) {
    $fileCount = $filesToCopy.Count
    $currentFile = 0

    foreach ($file in $filesToCopy) {
        $currentFile++
        $statusMessage = "Copying file $currentFile of $fileCount"
        Write-Progress -Activity "Copying files" -Status $statusMessage -PercentComplete ($currentFile / $fileCount * 100)

        $relativePath = $file.DirectoryName.Substring($source.Length)
        $destinationPath = Join-Path -Path $destination -ChildPath $relativePath

        if (-not (Test-Path $destinationPath)) {
            New-Item -ItemType Directory -Path $destinationPath -Force -Verbose | Out-Null
        }

        $finalDestination = Join-Path -Path $destinationPath -ChildPath $file.Name
        Copy-Item -Path $file.FullName -Destination $finalDestination -Verbose
        Write-Host "Copied to: $finalDestination"
    }

    Write-Progress -Activity "Copying files" -Status "Completed" -Completed
}

function Cleanup-OldBackups($destination) {
    Write-Host "Cleaning up old backups at $destination"

    # Get all .bak files in each backup folder
    $backupFiles = Get-ChildItem -Path $destination -Filter *.bak -Recurse -Verbose

    # Group these files by directory
    $groupedBackupFiles = $backupFiles | Group-Object { $_.DirectoryName }

    foreach ($group in $groupedBackupFiles) {
        # Exclude the latest backup file in each group from deletion
        $group.Group | Sort-Object LastWriteTime -Descending | Select-Object -Skip 1 | ForEach-Object {
            Write-Host "Removing old backup file: $($_.FullName)"
            Remove-Item $_.FullName -Force -Verbose
        }
    }
}

function Cleanup-EmptyDirectories($rootPath) {
    Write-Host "Cleaning up empty directories in $rootPath"

    Get-ChildItem -Path $rootPath -Directory -Recurse -Verbose |
        Where-Object { $_.GetFileSystemInfos().Count -eq 0 } |
        ForEach-Object {
            Write-Host "Removing empty directory: $($_.FullName)"
            Remove-Item $_.FullName -Force -Verbose
        }
}

# Check if there are files to copy and then copy them to the remote locations
if ($filesToCopy.Count -gt 0) {
    try {
        Copy-WithProgress -source $localFiles -destination $remotePathPL -filesToCopy $filesToCopy 
        Cleanup-OldBackups -destination $remotePathPL
        Cleanup-EmptyDirectories -rootPath $remotePathPL

        Copy-WithProgress -source $localFiles -destination $remotePathWKS -filesToCopy $filesToCopy
        Cleanup-OldBackups -destination $remotePathWKS
        Cleanup-EmptyDirectories -rootPath $remotePathWKS

        Write-Host "Files copied and old backups and empty directories cleaned successfully."
    } catch {
        Write-Host "Error during operation: $_"
    }
} else {
    Write-Host "No new .bak files to copy today."
}

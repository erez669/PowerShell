# Define the path for local backup files
$localFiles = "C:\yarpadb\sql_Backup"

# Initialize an array to hold files to be copied
$filesToCopy = @()

# Get a list of all subdirectories containing backup files
$backupFolders = Get-ChildItem -Path $localFiles -Directory -Recurse -Verbose

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
            New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        }

        $finalDestination = Join-Path -Path $destinationPath -ChildPath $file.Name
        Copy-Item -Path $file.FullName -Destination $finalDestination
        Write-Host "Copied to: $finalDestination"
    }

    Write-Progress -Activity "Copying files" -Status "Completed" -Completed
}

# Check if there are files to copy and then copy them to the remote locations
if ($filesToCopy.Count -gt 0) {
    try {
        Copy-WithProgress -source $localFiles -destination $remotePathPL -filesToCopy $filesToCopy 
        Copy-WithProgress -source $localFiles -destination $remotePathWKS -filesToCopy $filesToCopy
        Write-Host "Files copied successfully."
    } catch {
        Write-Host "Error copying files: $_"
    }
} else {
    Write-Host "No new .bak files to copy today."
}

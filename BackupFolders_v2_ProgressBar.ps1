# Define the path for local backup files
$localFiles = "C:\yarpadb\sql_Backup"

# Get today's date
$today = (Get-Date).Date

# Get only .bak files modified today
$files = Get-ChildItem -Path $localFiles -Filter *.bak -Recurse -Verbose | Where-Object { $_.LastWriteTime -gt $today }

# Extract the appropriate number from the hostname
if ($env:COMPUTERNAME -match 'WKS-(\d+)-\d{3}') {
    # If hostname follows the WKS-xxx-yyy pattern, extract the middle number (xxx)
    $serverNum = $Matches[1]
} elseif ($env:COMPUTERNAME -match '\d{3}$') {
    # Otherwise, if hostname ends with three digits, extract these
    $serverNum = $Matches[0]
} else {
    Write-Host "The hostname does not match expected patterns."
    exit
}

Write-Host "Snif number detected: $serverNum"

$remotePathPL = "\\PLPOSSRV$serverNum\E$\YarpaBackup_$serverNum"
$remotePathWKS = "\\WKS-$serverNum-102\C$\YarpaBackup_$serverNum"

# Function to copy files with progress and remove old backups
function Copy-WithProgress($source, $destination, $filesToCopy) {
    # Try to remove old .bak files from the destination, handling errors gracefully
    $existingBackups = Get-ChildItem -Path $destination -Filter *.bak -Recurse -ErrorAction SilentlyContinue
    foreach ($backup in $existingBackups) {
        try {
            Remove-Item $backup.FullName -Force -ErrorAction Stop
        } catch {
            Write-Host "Could not remove file: $($backup.FullName). Error: $_"
        }
    }

    $fileCount = $filesToCopy.Count
    $currentFile = 0

    foreach ($file in $filesToCopy) {
        $currentFile++
        $percentComplete = ($currentFile / $fileCount) * 100
        Write-Progress -Activity "Copying files to $destination" -Status "$currentFile of $fileCount" -PercentComplete $percentComplete

        $destinationPath = $file.FullName.Replace($source, $destination)
        $destinationDir = [System.IO.Path]::GetDirectoryName($destinationPath)

        if (-not (Test-Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir | Out-Null
        }

        Copy-Item -Path $file.FullName -Destination $destinationPath
    }

    Write-Progress -Activity "Copying files to $destination" -Completed
}

# Check if there are files to copy
if ($files.Count -gt 0) {
    # Copy the files to the remote servers
    Copy-WithProgress -source $localFiles -destination $remotePathPL -filesToCopy $files
    Copy-WithProgress -source $localFiles -destination $remotePathWKS -filesToCopy $files

    Write-Host "Files copied successfully."
} else {
    Write-Host "No new .bak files to copy today."
}

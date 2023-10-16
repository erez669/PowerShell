$localFiles = "C:\yarpadb\sql_Backup"
$files = Get-ChildItem -Path $localFiles -Recurse

# Extract the last three characters from the hostname
$serverNum = $env:COMPUTERNAME -match '\d{3}$'
if ($Matches[0]) {
    $serverNum = $Matches[0]
    $remotePathPL = "\\PLPOSSRV$serverNum\E$\YarpaBackup_$serverNum"
    $remotePathWKS = "\\WKS-$serverNum-102\C$\YarpaBackup_$serverNum"

    Write-Host "Server number detected: $serverNum"

    # Function to copy files with progress
    function Copy-WithProgress($source, $destination) {
        $fileCount = $files.Count
        $currentFile = 0
        
        foreach ($file in $files) {
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

    # Copy the files to the remote servers
    Copy-WithProgress -source $localFiles -destination $remotePathPL
    Copy-WithProgress -source $localFiles -destination $remotePathWKS

    Write-Host "Files copied successfully."

} else {
    Write-Host "The hostname does not end with three digits."
}
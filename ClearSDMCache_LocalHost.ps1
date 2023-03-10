Clear-Host

$ErrorActionPreference = "SilentlyContinue"

$Folders = @(
    "D:\sdmcache",
    "C:\Program Files (x86)\Landesk\ldclient\sdmcache",
    "C:\Program Files\Landesk\ldclient\sdmcache"
)

Foreach ($Folder in $Folders) {
    Write-Host -ForegroundColor Yellow "Deleting Folder $Folder on $env:computername"
    Get-ChildItem -Path $Folder -Recurse -Verbose | Remove-Item -Recurse -Force -Verbose
}

# Delete empty folders and subfolders
Foreach ($Folder in $Folders) {
    Get-ChildItem $Folder -Directory -Recurse -Verbose `
        | Sort-Object { $_.FullName.Length } -Descending `
        | Where-Object { $_.GetFiles().Count -eq 0 } `
        | ForEach-Object {
            if ($_.GetDirectories().Count -eq 0) { 
                Write-Host "Removing $($_.FullName)"
                $_.Delete()
            }
        }
}

$ExcludeFolder = "D:\folder"

Foreach ($Folder in $Folders) {
    if ($Folder -ne $ExcludeFolder) {
        Write-Host -ForegroundColor Green "Creating Directory $Folder on $env:computername"
        New-Item -ItemType Directory -Path $Folder -Force
    } else {
        Write-Host -ForegroundColor Yellow "Skipping directory $Folder on $env:computername"
    }
}

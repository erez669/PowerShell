Clear-Host

$ErrorActionPreference = "SilentlyContinue"

$folderlist = @(
    "C$\Program Files (x86)\LANDesk\LDClient\sdmcache",
    "C$\Program Files\LANDesk\LDClient\sdmcache",
    "D$\sdmcache",
    "D$\folder"
)

$excludefolder = "D$\folder"

$computerlist = Get-Content -Path "\\sysinstalls\supergsrv\HdMatte\PowerShell\Servers.txt"

foreach ($folder in $folderlist) {
    foreach ($computer in $computerlist) {
        Write-Host -ForegroundColor Yellow "Deleting contents of $folder on $computer"

        $newfilepath = Join-Path "\\$computer\" $folder
        if (Test-Connection -ComputerName $computer -Quiet) {
            if ($folder -ne $excludefolder) {
                Get-ChildItem $newfilepath -Recurse -Force -Verbose | Remove-Item -Recurse -Force -Verbose
                Write-Host -ForegroundColor Green "Creating Directory $Folder on $computer"
                New-Item -ItemType Directory -Force -Path $newfilepath -Verbose | Out-Null
            }
        } else {
            Write-Warning "Could not connect to $computer"
        }
    }
}

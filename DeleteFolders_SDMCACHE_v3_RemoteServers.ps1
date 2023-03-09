clear-host

$ErrorActionPreference = "silentlycontinue"

$folderlist = @("C$\Program Files (x86)\LANDesk\LDClient\sdmcache","C$\Program Files\LANDesk\LDClient\sdmcache","D$\sdmcache","D$\supersol")

$computerlist = Get-Content -Path "\\sysinstalls\supergsrv\HdMatte\PowerShell\Servers.txt"

foreach ($file in $folderlist){
    foreach ($computer in $computerlist){
        Write-Host -ForegroundColor Yellow "Deleting contents of $file on $computer"

        $newfilepath = Join-Path "\\$computer\" "$file"
        if (Test-Connection -ComputerName $computer -Quiet) {
            Get-ChildItem $newfilepath -Recurse -Force -Verbose | Remove-Item -Recurse -Force -Verbose
            New-Item -ItemType Directory -Force -Path $newfilepath -Verbose | Out-Null
        } else {
            Write-Warning "Could not connect to $computer"
        }
    }
}
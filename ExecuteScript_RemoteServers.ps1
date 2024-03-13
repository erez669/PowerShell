$servers = Get-Content '\\10.251.10.251\supergsrv\HdMatte\PowerShell\Servers.txt'

foreach ($server in $servers) {
    # Establish a session for each server
    $session = New-PSSession -ComputerName $server
    
    # Execute the script on the D: partition of the server
    Invoke-Command -Session $session -ScriptBlock {
        Set-Location D:\
        .\DeleteFolders_SDMCACHE_v2.ps1
    }

    # Close the session
    Remove-PSSession -Session $session
}
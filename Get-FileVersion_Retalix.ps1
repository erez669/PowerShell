Clear-Host

$workstations = Get-Content \\10.251.10.251\supergsrv\HdMatte\PowerShell\Computers.txt
$outputFile = 'C:\Temp\Retalix_Version.csv'
$paths = @(
    'c:\retalix\wingpos\GroceryWinPos.exe',
    'c:\Program Files (x86)\Retalix\SCO.NET\App\sco.exe',
    'c:\Program Files\Retalix\SCO.NET\App\sco.exe'
)

$runspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
$runspacePool.Open()

$runspaces = @()

foreach ($pc in $workstations) {
    Write-Host "Starting runspace for $pc" -ForegroundColor Green
    $runspace = [powershell]::Create().AddScript({
        param($pc, $paths, $outputFile)
        Write-Host "Checking files on '$pc':" -ForegroundColor Yellow
        foreach ($path in $paths) {
            Write-Host "Checking path $path on $pc" -ForegroundColor Cyan
            $result = Invoke-Command -ComputerName $pc -ScriptBlock {param($path) if (Test-Path $path) {Get-ChildItem $path | Select-Object VersionInfo}} -ArgumentList $path
            if ($result) {
                $version = $result.VersionInfo.FileVersion
                Write-Host "Found version $version at $path on $pc" -ForegroundColor Magenta
                $data = New-Object PSObject -Property @{
                    PSComputerName = $pc
                    FilePath = $path
                    FileVersion = $version
                }
                $data | Export-Csv -Path $outputFile -Append -Verbose -Force -Encoding UTF8 -NoTypeInformation
                break
            }
        }
    }).AddArgument($pc).AddArgument($paths).AddArgument($outputFile)

    $runspace.RunspacePool = $runspacePool
    $runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke(); Hostname = $pc }
}

while ($runspaces.Count -gt 0) {
    $completed = $runspaces | Where-Object { $_.Status.IsCompleted -eq $true }
    foreach ($runspace in $completed) {
        Write-Host "Runspace for $($runspace.Hostname) completed" -ForegroundColor Green
        $runspace.Pipe.EndInvoke($runspace.Status)
        $runspace.Pipe.Dispose()
        $runspaces = $runspaces | Where-Object { $_ -ne $runspace }
    }
    if ($runspaces.Count -gt 0) {
        Start-Sleep -Milliseconds 100
    }
}

Write-Host "All runspaces completed" -ForegroundColor Green
$runspacePool.Close()
$runspacePool.Dispose()

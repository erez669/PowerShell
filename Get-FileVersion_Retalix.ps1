Clear-Host
$workstations = Get-Content \\10.251.10.251\supergsrv\HdMatte\PowerShell\Computers.txt
$outputFile = 'C:\Temp\Retalix_Version.csv'
$paths = @(
    'c:\retalix\wingpos\GroceryWinPos.exe',
    'c:\Program Files (x86)\Retalix\SCO.NET\App\sco.exe',
    'c:\Program Files\Retalix\SCO.NET\App\sco.exe'
)

foreach ($pc in $workstations) {
    Write-Host "Checking files on '$pc':" -ForegroundColor Yellow -Verbose
    foreach ($path in $paths) {
        $result = Invoke-Command -ComputerName $pc -ScriptBlock {param($path) if (Test-Path $path) {Get-ChildItem $path | Select-Object VersionInfo}} -ArgumentList $path
        if ($result) {
            $version = $result.VersionInfo.FileVersion
            $data = New-Object PSObject -Property @{
                PSComputerName = $pc
                FilePath = $path
                FileVersion = $version
            }
            $data | Export-Csv -Path $outputFile -Append -Verbose -Force -Encoding UTF8 -NoTypeInformation
            break
        }
    }
}
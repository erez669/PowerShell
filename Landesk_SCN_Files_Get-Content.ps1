$directory = "E:\LANDesk\ManagementSuite\ldscan\ErrorScan"
$outputFile = "E:\LANDesk\ManagementSuite\ldscan\OutPut-scn.csv"

$deviceNames = @()

Get-ChildItem -Path $directory -Filter *.scn | ForEach-Object {
    Write-Host "Processing file: $($_.FullName)"
    $content = Get-Content $_.FullName -Raw
    if ($content -match 'Device Name =(.+?)\r?\n') {
        $deviceName = $matches[1].Trim()
        Write-Host "Device Name found: $deviceName"
        $deviceNames += [PSCustomObject]@{
            DeviceName = $deviceName
            FileName = $_.Name
        }
    }
    else {
        Write-Host "No Device Name found in $($_.FullName)"
    }
}

$deviceNames | Export-Csv -Path $outputFile -NoTypeInformation
Write-Host "Exported to $outputFile"

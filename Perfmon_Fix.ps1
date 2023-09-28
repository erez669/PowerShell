$filePath = "C:\install\Counters.txt"

# Export the current performance counter configuration to a file
lodctr /q | Out-File -FilePath $filePath

# Read the content of the file
$counters = Get-Content $filePath

# Iterate through each line and enable disabled counters
foreach ($counter in $counters) {
    if ($counter -match "^\[.*\].*\(Disabled\)$") {
        $serviceName = ($counter -split "\[|\]")[1]
        Write-Host "Enabling counter: $serviceName"
        lodctr "/e:`"$serviceName`""
    }
}

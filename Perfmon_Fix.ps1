$filePath = "C:\install\Counters.txt"

# Export the current performance counter configuration to a file
lodctr /q > $filePath

# Read the content of the file
$counters = Get-Content $filePath

# Iterate through each line and enable disabled counters
$counters | ForEach-Object {
    if ($_ -match "^\[.*\].*\(Disabled\)$") {
        $serviceName = ($_ -split "\[|\]")[1]
        Write-Host "Enabling counter: $serviceName"
        lodctr "/e:`"$serviceName`""
    }
}
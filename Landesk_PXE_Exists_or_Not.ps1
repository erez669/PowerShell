Clear-Host

# Array of service names to check
$services = @("LANDesk(R) PXE Service" , "LANDesk(R) PXE MTFTP Service")

# Output file path
$outputFile = "\\ivantiappsrv\IvantiShare\Packages\-Witness-\PXE_Force\PXE_List.txt"

# Check each service on the Array
foreach($service in $services) {
    $serviceStatus = Get-Service $service -ErrorAction SilentlyContinue -Verbose

    if($serviceStatus) {
        # If service exists, add it to the output file
        Add-Content -Path $outputFile -Value ( ("Hostname: {0,-15} Service: {1,-40}" -f $env:computername, $service).PadRight(70) + "Status: Service Exists")
    } else {
        # If service does not exist, add it to the output file
        Add-Content -Path $outputFile -Value ( ("Hostname: {0,-15} Service: {1,-40}" -f $env:computername, $service).PadRight(70) + "Status: Service does not exists")
    }
}
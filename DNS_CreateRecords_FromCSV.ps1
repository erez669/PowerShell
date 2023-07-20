Clear-Host

# Import the Active Directory module
Import-Module DnsServer

$csvFilePath = "C:\PowerShell_ErezSc\Wall_Shopic.csv"
$csvContent = Import-Csv -Path $csvFilePath
$csvContent | Format-Table

# Specify your DNS servers
$DNSServers = "10.250.207.150", "10.250.207.151", "10.250.207.152"

# Specify the CSV file path
$csvFilePath = "C:\PowerShell_ErezSc\Wall_Shopic.csv"

# Import the CSV file
$csv = Import-Csv -Path $csvFilePath

# Loop through each record in the CSV file
foreach ($record in $csv) {
    # Check if 'IPAddress' field is null or empty
    if (![string]::IsNullOrEmpty($record.IPAddress)) {
        # Loop through each DNS server
        foreach ($server in $DNSServers) {
            # Check if RecordType is 'A'
            if ($record.RecordType -eq 'A') {
                # Check if DNS A record already exists
                $existingRecords = Get-DnsServerResourceRecord -ComputerName $server -ZoneName "posprod.supersol.co.il" -RRType "A" -Name $record.Hostname -ErrorAction SilentlyContinue -Verbose
                if ($null -ne $existingRecords) {
                    # If record exists and is not a 'empty' record, delete it
                    foreach($existingRecord in $existingRecords){
                        if ($null -ne $existingRecord.RecordData) {
                            Remove-DnsServerResourceRecord -ComputerName $server -ZoneName "posprod.supersol.co.il" -InputObject $existingRecord -Force -Verbose -ErrorAction SilentlyContinue
                        }
                    }
                }

                # Add new DNS A record
                Add-DnsServerResourceRecordA -ComputerName $server -ZoneName "posprod.supersol.co.il" -Name $record.Hostname -IPv4Address $record.IPAddress -CreatePtr -Verbose -ErrorAction SilentlyContinue
            }
            else {
                Write-Host ("RecordType '" + $record.RecordType + "' is not supported.")
            }
        }
    } else {
        Write-Host ("Record with HostName '" + $record.Hostname + "' has null or empty 'IPAddress' field.")
    }
}
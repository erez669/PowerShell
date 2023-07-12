Clear-Host

$csv = Import-Csv -Path 'C:\Users\erezsc\Desktop\IPAddress.csv'

foreach ($row in $csv) {
    $ipParts = $row.IPAddress -split '\.'
    $newIpParts = $ipParts | ForEach-Object { [int]$_ }
    $newIp = $newIpParts -join '.'
    $row.IPAddress = $newIp
}

$csv | Export-Csv 'C:\Users\erezsc\Desktop\IPAddress_Fixed.csv' -NoTypeInformation

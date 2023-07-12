Clear-Host

$csv = Import-Csv -Path 'C:\Users\erezsc\Desktop\CSS.csv'

foreach ($row in $csv) {
    $ipParts = $row.IPAddress -split '\.'
    $newIpParts = $ipParts | ForEach-Object { [int]$_ }
    $newIp = $newIpParts -join '.'
    $row.IPAddress = $newIp
}

$csv | Export-Csv 'C:\Users\erezsc\Desktop\CSS_Fixed.csv' -NoTypeInformation
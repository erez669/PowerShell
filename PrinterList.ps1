while ($true) {
cls
write-host "Get Printer List from Printer Server"
write-host "`n" # for creating space
$printserver = read-host "enter printer server name"

try { 
    Get-Printer -ComputerName $printserver -ErrorAction Stop | 
    Select-Object name, portname -Unique | 
    out-file "\\10.251.10.251\Supergsrv\HdMatte\NetworkPrinterList\PrinterList-$printserver.txt"
    Invoke-Item "\\10.251.10.251\Supergsrv\HdMatte\NetworkPrinterList\PrinterList-$printserver.txt"
} catch {
    Write-Error $_.message
}

}
$while

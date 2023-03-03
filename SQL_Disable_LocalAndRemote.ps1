Clear-Host
$instance1 = "SQL Server (MSSQLSERVER)"
$instance2 = "SQL Server Agent (MSSQLSERVER)"
$instance3 = "World Wide Web Publishing Service"
$computerName = $env:COMPUTERNAME

Stop-Service -DisplayName $instance1 -Force
$service1 = Get-WmiObject -Class Win32_Service -Filter "DisplayName='$instance1'"
$service1.ChangeStartMode("Disabled")
Stop-Service -DisplayName $instance2 -Force
$service2 = Get-WmiObject -Class Win32_Service -Filter "DisplayName='$instance2'"
$service2.ChangeStartMode("Disabled")
Stop-Service -DisplayName $instance3 -Force
$service3 = Get-WmiObject -Class Win32_Service -Filter "DisplayName='$instance3'"
$service3.ChangeStartMode("Disabled")
Write-Host "The services '$instance1','$instance2' and $instance3 on '$computerName' have been stopped"

$secondaryServer = 'S' + $computerName.Substring(1)
$serviceName1 = "MSSQLSERVER"
$serviceName2 = "SQLSERVERAGENT"
$serviceName3 = "W3SVC"
Invoke-Command -ComputerName $secondaryServer -ScriptBlock {
    Stop-Service -Name $using:serviceName1 -Force
    Set-Service -Name $using:serviceName1 -StartupType Disabled
    Stop-Service -Name $using:serviceName2 -Force
    Set-Service -Name $using:serviceName2 -StartupType Disabled
    Stop-Service -Name $using:serviceName3 -Force
    Set-Service -Name $using:serviceName3 -StartupType Disabled
}
Write-Host "The services '$instance1','$instance2' and $instance3 on computer '$secondaryServer' have been stopped"

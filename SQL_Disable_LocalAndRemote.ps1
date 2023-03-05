Clear-Host
$instance1 = "SQL Server (MSSQLSERVER)"
$instance2 = "SQL Server Agent (MSSQLSERVER)"
$instance3 = "World Wide Web Publishing Service"
$computerName = $env:COMPUTERNAME

$serviceName1 = "MSSQLSERVER"
$serviceName2 = "SQLSERVERAGENT"
$serviceName3 = "W3SVC"

Stop-Service -DisplayName $instance1 -Force
$service1 = Get-WmiObject -Class Win32_Service -Filter "DisplayName='$instance1'"
$service1.ChangeStartMode("Disabled")
Stop-Service -DisplayName $instance2 -Force
$service2 = Get-WmiObject -Class Win32_Service -Filter "DisplayName='$instance2'"
$service2.ChangeStartMode("Disabled")
Stop-Service -DisplayName $instance3 -Force
$service3 = Get-WmiObject -Class Win32_Service -Filter "DisplayName='$instance3'"
$service3.ChangeStartMode("Disabled")
Write-Host "The services '$instance1','$instance2' and $instance3' on '$computerName' have been stopped"

$secondaryServer = 'S' + $computerName.Substring(1)

Invoke-Command -ComputerName $secondaryServer -ArgumentList $serviceName1, $serviceName2, $serviceName3 -ScriptBlock {
    param($serviceName1, $serviceName2, $serviceName3)

    Stop-Service -Name $serviceName1 -Force
    Set-Service -Name $serviceName1 -StartupType Disabled
    Stop-Service -Name $serviceName2 -Force
    Set-Service -Name $serviceName2 -StartupType Disabled
    Stop-Service -Name $serviceName3 -Force
    Set-Service -Name $serviceName3 -StartupType Disabled
}
Write-Host "The services '$instance1','$instance2' and $instance3' on computer '$secondaryServer' have been stopped"

param ([switch]$Elevated)  
function Test-Admin {  
  $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())  
  $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) 
}  

if ((Test-Admin) -eq $false) {  
  if ($elevated) {  
    # tried to elevate, did not work, aborting  
  } else {  
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file \"{0}\" -elevated' -f ($myinvocation.MyCommand.Definition))  
  }  
  exit 
}  

Clear-Host

'running with full privileges'

# Define services and their names
$services = @{
    "SQL Server (MSSQLSERVER)" = "MSSQLSERVER"
    "SQL Server Agent (MSSQLSERVER)" = "SQLSERVERAGENT"
    "SQL Server CEIP service (MSSQLSERVER)" = "SQLTELEMETRY"
    "World Wide Web Publishing Service" = "W3SVC"
    "SQL Full-text Filter Daemon Launcher (MSSQLSERVER)" = "MSSQLFDLauncher"
    "SQL Server VSS Writer" = "SQLWriter"
    "SQL Active Directory Helper Service" = "MSSQLServerADHelper100"
}

# Get current computer name
$computerName = $env:COMPUTERNAME

# Stop, disable and set recovery options for each service
foreach ($displayName in $services.Keys) {
    $serviceName = $services[$displayName]

    if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
        Stop-Service -DisplayName $displayName -Force -Verbose
        $service = Get-WmiObject -Class Win32_Service -Filter "DisplayName='$displayName'"
        $service.ChangeStartMode("Disabled")

        # Change recovery options to 'take no action'
        & sc.exe failure $serviceName reset= 0 actions= none/0/none/0/none/0
    }
}

Write-Host "The services '$($services.Keys -join ', ')' on '$computerName' have been stopped"

# Define secondary server name
$secondaryServer = 'S' + $computerName.Substring(1)

# Stop, disable and set recovery options for services on secondary server
Invoke-Command -ComputerName $secondaryServer -ArgumentList $services.Values -ScriptBlock {
    param($serviceNames)

    foreach ($serviceName in $serviceNames) {
        if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
            Stop-Service -Name $serviceName -Force -Verbose
            Set-Service -Name $serviceName -StartupType Disabled

            # Change recovery options to 'take no action'
            & sc.exe failure $serviceName reset= 0 actions= none/0/none/0/none/0
        }
    }
}

Write-Host "The services '$($services.Keys -join ', ')' on computer '$secondaryServer' have been stopped"

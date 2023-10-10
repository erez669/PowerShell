If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}

Clear-Host

Install-WindowsFeature -Name 'DHCP' –IncludeManagementTools

# dhcp scope variables
$srvName = [System.Net.Dns]::GetHostName()
$1stNum = $srvName.Substring($srvName.Length -3 ,3)[0]
$2ndNum = $srvName.Substring($srvName.Length -3 ,3)[1]
$3rdNum = $srvName.Substring($srvName.Length -3 ,3)[2]

$strOctet = "$2ndNum$3rdNum"
$intOctet = [int]$strOctet

$1stvLan = "10.1$1stNum.$intOctet.0"
$2ndvLan = "10.11$1stNum.$intOctet.0"

$scopename1 = "Vlan1"
$startrange1 = "10.1$1stNum.$intOctet.131"
$endrange1 = "10.1$1stNum.$intOctet.150"
$subnetmask = "255.255.255.0"
$router1 = "10.1$1stNum.$intOctet.254"

$scopename2 = "Vlan2"
$startrange2 = "10.11$1stNum.$intOctet.140"
$endrange2 = "10.11$1stNum.$intOctet.150"
$router2 = "10.11$1stNum.$intOctet.254"

$DNS1 = "10.250.207.150"
$DNS2 = "10.250.207.151"

# Creating scopes
Add-DHCPServerv4Scope -StartRange $startrange1 -EndRange $endrange1 -SubnetMask $subnetmask -Name $scopename1 -State Active
Add-DHCPServerv4Scope -StartRange $startrange2 -EndRange $endrange2 -SubnetMask $subnetmask -Name $scopename2 -State Active

# Adding Scope Options
Set-DHCPServerv4OptionValue -Router $router1 -ScopeId $1stvLan
Set-DHCPServerv4OptionValue -Router $router2 -ScopeId $2ndvLan
Set-DHCPServerv4OptionValue -DnsServer $DNS1, $DNS2 -DnsDomain posprod.supersol.co.il
Set-DHCPServerv4OptionValue -Router $router1, $router2

# set value for Option 60 globally (for all scopes):
Add-DhcpServerv4OptionDefinition -OptionId 60 -Name PXEClient -Description "PXE Support" -Type String
Set-DhcpServerv4OptionValue -OptionId 60 -Value "PXEClient"
Restart-service dhcpserver

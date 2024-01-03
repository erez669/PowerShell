If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}

# Enable verbose output
$VerbosePreference = 'Continue'

# Modify the registry to set UTF-8 support
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"

# Set ACP (ANSI Code Page)
Set-ItemProperty -Path $registryPath -Name "ACP" -Value "65001"

# Set OEMCP (OEM Code Page)
Set-ItemProperty -Path $registryPath -Name "OEMCP" -Value "65001"

# Set MACCP (MAC Code Page)
Set-ItemProperty -Path $registryPath -Name "MACCP" -Value "65001"

# Output the updated values
Get-ItemProperty -Path $registryPath -Name "ACP", "OEMCP", "MACCP"
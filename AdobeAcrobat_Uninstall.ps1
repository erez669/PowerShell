If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}

# Terminate any running Adobe Acrobat processes
Get-Process | Where-Object { $_.ProcessName -like "Adob*" -or $_.ProcessName -like "Acro*" } -Verbose | Stop-Process -Force -Verbose

$uninstallKeys = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue
$adobeKey = $uninstallKeys | Get-ItemProperty | Where-Object { $_.DisplayName -match "Adobe Acrobat" } | Select-Object -First 1
if ($adobeKey) {
    Write-Host "Detected $($adobeKey.DisplayName), uninstalling..."
    $uninstallString = $adobeKey.UninstallString
    if ($uninstallString.StartsWith("MsiExec.exe")) {
        $uninstallString = $uninstallString -replace 'MsiExec.exe /I','MsiExec.exe /X'
    }
    Start-Process cmd -ArgumentList "/c $uninstallString /quiet /norestart" -WindowStyle Hidden -Wait
    Write-Host "Uninstallation complete."
} else {
    Write-Host "Adobe Acrobat not found."
}
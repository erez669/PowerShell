@echo off
echo ****** Get Printer List from Printer Server ****** 
pushd "%~dp0"
powershell.exe -Command "Start-Process powershell \"new-item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\powershell' -force"" -Verb RunAs"
powershell.exe -Command "Start-Process powershell \"Set-Itemproperty -path HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell -name ExecutionPolicy -value ByPass"" -Verb RunAs"
powershell.exe -Command "Start-Process powershell \"new-Itemproperty -path HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell -name EnableScripts -PropertyType Dword -Value 1 -force"" -Verb RunAs"
powershell.exe -Command "Start-Process 'cmd' -Verb RunAs -ArgumentList '/c "powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0PrinterList.ps1"'"

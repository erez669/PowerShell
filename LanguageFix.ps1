<#
new-item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\powershell' -force
Set-Itemproperty -path HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell -name ExecutionPolicy -value ByPass -force
new-Itemproperty -path HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell -name EnableScripts -PropertyType Dword -Value 1 -force
#>
Import-Module International
$LangList = Get-WinUserLanguageList
$MarkedLang = $LangList | where LanguageTag -eq "he"
$LangList.Remove($MarkedLang)
Set-WinUserLanguageList $LangList -Force
$languageList = New-WinUserLanguageList -Language he-IL
$languageList[0].InputMethodTips.Clear()
Set-WinUserLanguageList he-IL -Force
$LangList.Add("en-US")
$LangList.Add("he-IL")
Set-WinUserLanguageList -LanguageList $LangList -Force
Set-WinUserLanguageList -LanguageList en-US, he-IL -force
Set-WinSystemLocale -systemlocale he-IL
Set-WinHomeLocation -GeoId 117
Set-WinCultureFromLanguageListOptOut -OptOut 0
Set-WinUILanguageOverride -Language en-US
Set-WinDefaultInputMethodOverride -InputTip "0409:00000409"
set-culture 'he-IL'

# Changing the WelcomeScreen to fit the default layout
REG DELETE "HKEY_USERS\.DEFAULT\Keyboard Layout\Preload" /f
REG LOAD "HKU\DefaultUserTemplate" "C:\Users\Default\ntuser.dat"
REG DELETE "HKU\DefaultUserTemplate\Keyboard Layout\Preload" /f
REG ADD "HKU\DefaultUserTemplate\Keyboard Layout\Preload" /f
REG ADD "HKU\DefaultUserTemplate\Keyboard Layout\Preload" /v "1" /t REG_SZ /d 00000409 /f
REG ADD "HKU\DefaultUserTemplate\Keyboard Layout\Preload" /v "2" /t REG_SZ /d 0000040d /f
REG UNLOAD "HKU\DefaultUserTemplate"
Write-Output "Successfully Changing the default keyboard layout"
rundll32.exe shell32,Control_RunDLL intl.cpl
# Remove-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\powershell' -force
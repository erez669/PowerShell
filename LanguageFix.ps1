# Get the ID and security principal of the current user account
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)

# Get the security principal for the Administrator role
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator

# Check to see if we are currently running "as Administrator"
if ($myWindowsPrincipal.IsInRole($adminRole))
{
   # We are running "as Administrator" - so change the title and background color to indicate this
   $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
   $Host.UI.RawUI.BackgroundColor = "DarkBlue"
   clear-host
}
else
{
   # We are not running "as Administrator" - so relaunch as administrator

   # Create a new process object that starts PowerShell
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";

   # Specify the current script path and name as a parameter
   $newProcess.Arguments = $myInvocation.MyCommand.Definition;

   # Indicate that the process should be elevated
   $newProcess.Verb = "runas";

   # Start the new process
   [System.Diagnostics.Process]::Start($newProcess);

   # Exit from the current, unelevated, process
   exit
}

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
& $env:SystemRoot\System32\control.exe "intl.cpl,,/f:"\\10.251.10.251\supergsrv\HdMatte\PowerShell\Lang.xml""
& $env:SystemRoot\System32\control.exe "intl.cpl,,1"

Clear-Host

# Function to set language and region settings
function Set-LanguageAndRegion {
    Import-Module International
    $LangList = Get-WinUserLanguageList
    $MarkedLang = $LangList | Where-Object LanguageTag -eq "he"
    if ($MarkedLang) {
        $LangList.Remove($MarkedLang)
    }
    Set-WinUserLanguageList $LangList -Force
    $languageList = New-WinUserLanguageList -Language he-IL
    $languageList[0].InputMethodTips.Clear()
    Set-WinUserLanguageList he-IL -Force
    $LangList.Add("en-US")
    $LangList.Add("he-IL")
    Set-WinUserLanguageList -LanguageList $LangList -Force
    Set-WinUserLanguageList -LanguageList en-US, he-IL -Force
    Set-WinSystemLocale -SystemLocale he-IL
    Set-WinHomeLocation -GeoId 117
    Set-WinCultureFromLanguageListOptOut -OptOut 0
    Set-WinUILanguageOverride -Language en-US
    Set-WinDefaultInputMethodOverride -InputTip "0409:00000409"
    Set-Culture 'he-IL'
}

# Apply language and region settings
Set-LanguageAndRegion

# Changing the WelcomeScreen to fit the default layout
$preloadKey = "Registry::HKEY_USERS\.DEFAULT\Keyboard Layout\Preload"
if (Test-Path $preloadKey) {
    Remove-Item $preloadKey -Force
}
New-Item -Path $preloadKey -Force
New-ItemProperty -Path $preloadKey -Name "1" -Value "00000409" -Force
New-ItemProperty -Path $preloadKey -Name "2" -Value "0000040d" -Force

$substitutesKey = "Registry::HKEY_USERS\.DEFAULT\Keyboard Layout\Substitutes"
if (-Not (Test-Path $substitutesKey)) {
    New-Item -Path $substitutesKey -Force
}
New-ItemProperty -Path $substitutesKey -Name "00000409" -Value "00000409" -Force
New-ItemProperty -Path $substitutesKey -Name "0000040d" -Value "0000040d" -Force

$defaultUserTemplate = "C:\Users\Default\ntuser.dat"
if (Test-Path $defaultUserTemplate) {
    Start-Process "reg.exe" -ArgumentList "load HKU\DefaultUserTemplate $defaultUserTemplate" -Wait -NoNewWindow
    
    $templatePreloadKey = "Registry::HKU\DefaultUserTemplate\Keyboard Layout\Preload"
    if (Test-Path $templatePreloadKey) {
        Remove-Item $templatePreloadKey -Force
    }
    New-Item -Path $templatePreloadKey -Force
    New-ItemProperty -Path $templatePreloadKey -Name "1" -Value "00000409" -Force
    New-ItemProperty -Path $templatePreloadKey -Name "2" -Value "0000040d" -Force

    $templateSubstitutesKey = "Registry::HKU\DefaultUserTemplate\Keyboard Layout\Substitutes"
    if (-Not (Test-Path $templateSubstitutesKey)) {
        New-Item -Path $templateSubstitutesKey -Force
    }
    New-ItemProperty -Path $templateSubstitutesKey -Name "00000409" -Value "00000409" -Force
    New-ItemProperty -Path $templateSubstitutesKey -Name "0000040d" -Value "0000040d" -Force

    # Apply settings for the welcome screen and new user accounts using PowerShell
    Set-ItemProperty -Path "Registry::HKU\DefaultUserTemplate\Control Panel\International" -Name "Locale" -Value "0000040d"
    Set-ItemProperty -Path "Registry::HKU\DefaultUserTemplate\Control Panel\International" -Name "LocaleName" -Value "he-IL"
    Set-ItemProperty -Path "Registry::HKU\DefaultUserTemplate\Control Panel\International" -Name "sCountry" -Value "Israel"
    Set-ItemProperty -Path "Registry::HKU\DefaultUserTemplate\Control Panel\International" -Name "sLanguage" -Value "HEB"
    Set-ItemProperty -Path "Registry::HKU\DefaultUserTemplate\Control Panel\International\User Profile" -Name "InputMethodOverride" -Value "0409:00000409"

    # Unload the hive and ensure it's unloaded
    $unloaded = $false
    while (-not $unloaded) {
        Start-Process "reg.exe" -ArgumentList "unload HKU\DefaultUserTemplate" -Wait -NoNewWindow
        Start-Sleep -Seconds 1
        $unloaded = -not (Test-Path "HKU:\DefaultUserTemplate")
    }
}

Write-Output "Successfully changed the default keyboard layout"

# Automate "Copy settings..." step by setting the appropriate registry keys
$path = "HKCU:\Control Panel\International\Geo"
if (-Not (Test-Path $path)) { New-Item -Path $path -Force }
Set-ItemProperty -Path $path -Name "Nation" -Value 117 -Force

$path = "HKCU:\Control Panel\International"
if (-Not (Test-Path $path)) { New-Item -Path $path -Force }
Set-ItemProperty -Path $path -Name "Locale" -Value "0000040d" -Force
Set-ItemProperty -Path $path -Name "LocaleName" -Value "he-IL" -Force
Set-ItemProperty -Path $path -Name "sCountry" -Value "Israel" -Force
Set-ItemProperty -Path $path -Name "sLanguage" -Value "HEB" -Force

# Apply settings for the welcome screen and new user accounts using PowerShell
Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\International" -Name "Locale" -Value "0000040d" -Force
Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\International" -Name "LocaleName" -Value "he-IL" -Force
Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\International" -Name "sCountry" -Value "Israel" -Force
Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\International" -Name "sLanguage" -Value "HEB" -Force
Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\International\User Profile" -Name "InputMethodOverride" -Value "0409:00000409" -Force

Write-Output "Successfully applied language settings to all profiles"

function Set-LanguageAndRegion {
    Import-Module International
    
    # Remove the Hebrew language if already present
    $LangList = Get-WinUserLanguageList
    $LangList = $LangList | Where-Object LanguageTag -ne "he"

    # Set the primary language and input method
    $languageList = New-WinUserLanguageList -Language he-IL
    $languageList[0].InputMethodTips.Clear()
    Set-WinUserLanguageList $languageList -Force

    # Add secondary languages
    $LangList.Add("en-US")
    $LangList.Add("he-IL")
    Set-WinUserLanguageList -LanguageList $LangList -Force

    # Set other regional settings
    Set-WinSystemLocale -SystemLocale he-IL
    Set-WinHomeLocation -GeoId 117
    Set-WinCultureFromLanguageListOptOut -OptOut 0
    Set-WinUILanguageOverride -Language en-US
    Set-WinDefaultInputMethodOverride -InputTip "0409:00000409"
    Set-Culture 'he-IL'
}

# Apply language and region settings
Set-LanguageAndRegion

# Function to update registry settings for the current user
function Update-CurrentUserRegistry {
    # Automate "Copy settings..." step by setting the appropriate registry keys
    $geoPath = "HKCU:\Control Panel\International\Geo"
    if (-Not (Test-Path $geoPath)) { New-Item -Path $geoPath -Force }
    Set-ItemProperty -Path $geoPath -Name "Nation" -Value 117 -Force

    $intlPath = "HKCU:\Control Panel\International"
    if (-Not (Test-Path $intlPath)) { New-Item -Path $intlPath -Force }
    Set-ItemProperty -Path $intlPath -Name "Locale" -Value "0000040d" -Force
    Set-ItemProperty -Path $intlPath -Name "LocaleName" -Value "he-IL" -Force
    Set-ItemProperty -Path $intlPath -Name "sCountry" -Value "Israel" -Force
    Set-ItemProperty -Path $intlPath -Name "sLanguage" -Value "HEB" -Force
}

# Function to update registry settings for the default user profile
function Update-DefaultUserRegistry {
    $defaultUserTemplate = "C:\Users\Default\ntuser.dat"
    if (Test-Path $defaultUserTemplate) {
        Start-Process "reg.exe" -ArgumentList "load HKU\DefaultUserTemplate $defaultUserTemplate" -Wait -NoNewWindow
        
        # Modify the default user template registry settings
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

        # Set the regional and language settings
        $intlPath = "Registry::HKU\DefaultUserTemplate\Control Panel\International"
        Set-ItemProperty -Path $intlPath -Name "Locale" -Value "0000040d" -Force
        Set-ItemProperty -Path $intlPath -Name "LocaleName" -Value "he-IL" -Force
        Set-ItemProperty -Path $intlPath -Name "sCountry" -Value "Israel" -Force
        Set-ItemProperty -Path $intlPath -Name "sLanguage" -Value "HEB" -Force
        Set-ItemProperty -Path "$intlPath\User Profile" -Name "InputMethodOverride" -Value "0409:00000409" -Force

        # Unload the registry hive
        do {
            Start-Process "reg.exe" -ArgumentList "unload HKU\DefaultUserTemplate" -Wait -NoNewWindow
            Start-Sleep -Seconds 1
        } while (Test-Path "HKU:\DefaultUserTemplate")
    }

    Write-Output "Successfully changed the default keyboard layout for new user profiles"
}

# Update the registry for the current user
Update-CurrentUserRegistry

# Update the registry for the default user profile
Update-DefaultUserRegistry

Write-Output "Successfully applied language settings to the current profile and default profile"

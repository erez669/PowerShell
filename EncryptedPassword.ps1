if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Red
    Write-Host "Please right-click on the PowerShell icon and select 'Run as administrator'." -ForegroundColor Yellow
    Write-Host "Then navigate to the script's directory and run it again." -ForegroundColor Yellow
    Exit 1
}

$hostname = $(hostname)
if ($hostname -notmatch "CSS$") {
    Write-Host "Error: The hostname of this computer does not end with 'CSS'." -ForegroundColor Red
    Write-Host "Current hostname: $hostname" -ForegroundColor Yellow
    Write-Host "This script is designed to run only on computers with hostnames ending in 'CSS'." -ForegroundColor Yellow
    Write-Host "Please check your computer's hostname and try again on an appropriate machine." -ForegroundColor Yellow
    Exit 7
}

Clear-Host

# Change to the script's directory
Push-Location $PSScriptRoot

# Disable Windows Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Enable Remote Desktop
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-TCP' -Name "UserAuthentication" -Value 1

$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$regName = "DontDisplayLastUserName"
$desiredValue = 1
# Function to get the current value, returns $null if the value doesn't exist
function Get-RegistryValue {
    Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue | 
    Select-Object -ExpandProperty $regName
}
$currentValue = Get-RegistryValue
if ($null -eq $currentValue) {
    # If the value doesn't exist, create it
    New-ItemProperty -Path $regPath -Name $regName -Value $desiredValue -PropertyType DWORD -Force
    Write-Host "Created new registry value '$regName' and set it to $desiredValue"
} elseif ($currentValue -ne $desiredValue) {
    # If the value exists but is different, update it
    Set-ItemProperty -Path $regPath -Name $regName -Value $desiredValue
    Write-Host "Updated existing registry value '$regName' from $currentValue to $desiredValue"
} else {
    # If the value already matches what we want, do nothing
    Write-Host "Registry value '$regName' is already set to $desiredValue. No changes made."
}

# Define encryption key and password file path
$encryptionKey = [byte[]]@(1..32)
$encryptedPasswordFile = "$PSScriptRoot\encrypted_password.txt"

# Check if encrypted password file exists, if not, create it
if (-not (Test-Path -Path $encryptedPasswordFile)) {
    $password = Read-Host -AsSecureString "Enter a new password to encrypt"
    $encrypted = ConvertFrom-SecureString -SecureString $password -Key $encryptionKey
    $encrypted | Out-File -FilePath $encryptedPasswordFile
    Write-Host "Password encrypted and stored successfully."
}

# Retrieve the securely stored password
$encryptedPassword = Get-Content -Path $encryptedPasswordFile -Raw
$securePassword = ConvertTo-SecureString $encryptedPassword -Key $encryptionKey

# Function to set user password and add to Administrators group
function Set-UserConfig {
    param ([string]$Username)
    
    # Check if the account is disabled and enable it if necessary
    $user = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
    if ($user -and $user.Enabled -eq $false) {
        Enable-LocalUser -Name $Username
        Write-Host "$Username account was disabled. It has been enabled."
    } elseif (-not $user) {
        Write-Host "$Username account not found. Unable to configure."
        return
    }
    
    Set-LocalUser -Name $Username -Password $securePassword -PasswordNeverExpires $true
    Add-LocalGroupMember -Group "Administrators" -Member $Username -ErrorAction SilentlyContinue
    Write-Host "$Username configured successfully."
}

# Configure Administrator account
Set-UserConfig -Username "Administrator"

# Configure NCR account
$userExists = Get-LocalUser -Name "User" -ErrorAction SilentlyContinue
if ($null -ne $userExists) {
    Rename-LocalUser -Name "User" -NewName "NCR"
} elseif (-not (Get-LocalUser -Name "NCR" -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name "NCR" -Password $securePassword -FullName "NCR" -Description "Standard User Account"
}
Set-UserConfig -Username "NCR"

# Return to the original directory
Pop-Location

Write-Host "Configuration completed successfully."

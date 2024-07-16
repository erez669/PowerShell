if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Red
    Write-Host "Please right-click on the PowerShell icon and select 'Run as administrator'." -ForegroundColor Yellow
    Write-Host "Then navigate to the script's directory and run it again." -ForegroundColor Yellow
    Exit 1
}

# Check if hostname ends with 'CSS'
$hostname = $(hostname)
if ($hostname -notmatch "CSS$") {
    Write-Error "Hostname does not end with 'CSS'. Exiting."
    Exit 7
}

Clear-Host

# uncomment next 4 lines to create the encrypted password file, after creation, you can remove this lines or comment them again

# $encryptionKey = [byte[]]@(1..32)
# $password = Read-Host -AsSecureString "Enter the password to encrypt"
# $encrypted = ConvertFrom-SecureString -SecureString $password -Key $encryptionKey
# $encrypted | Out-File -FilePath "$PSScriptRoot\encrypted_password.txt"

# Change to the script's directory
Push-Location $PSScriptRoot

# Disable Windows Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Enable Remote Desktop
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-TCP' -Name "UserAuthentication" -Value 1

# Define a fixed encryption key (32 bytes for AES-256)
$encryptionKey = [byte[]]@(1..32)

# Function to securely store password using AES encryption
function Set-EncryptedPassword {
    param (
        [string]$FilePath,
        [string]$Password
    )
    try {
        $secureString = ConvertTo-SecureString $Password -AsPlainText -Force
        $encrypted = ConvertFrom-SecureString $secureString -Key $encryptionKey
        $encrypted | Out-File -FilePath $FilePath
        Write-Host "Password encrypted and stored successfully."
    }
    catch {
        Write-Error "Failed to encrypt and store password: $_"
    }
}

# Function to retrieve securely stored password
function Get-EncryptedPassword {
    param (
        [string]$FilePath
    )
    try {
        if (-not (Test-Path -Path $FilePath)) {
            throw "Encrypted password file not found at $FilePath"
        }
        $encrypted = Get-Content -Path $FilePath -Raw
        if ([string]::IsNullOrWhiteSpace($encrypted)) {
            throw "Encrypted password file is empty"
        }
        $secureString = ConvertTo-SecureString $encrypted -Key $encryptionKey
        return $secureString
    }
    catch {
        Write-Error "Failed to retrieve encrypted password: $_"
        return $null
    }
}

# Retrieve the securely stored password
$securePassword = Get-EncryptedPassword -FilePath "$PSScriptRoot\encrypted_password.txt"
if ($null -eq $securePassword) {
    Write-Error "Failed to retrieve the secure password. Please ensure the password is correctly stored."
    Exit
}

# Function to securely set password
function Set-SecurePassword {
    param (
        [string]$Username,
        [System.Security.SecureString]$SecurePassword
    )
    try {
        Set-LocalUser -Name $Username -Password $SecurePassword
        Set-LocalUser -Name $Username -PasswordNeverExpires $true
        Write-Host "Password for $Username has been set securely and set to never expire."
    }
    catch {
        Write-Error "Failed to set password for $Username or set it to never expire: $_"
    }
}

# Enable and set password for Administrator account
try {
    Enable-LocalUser -Name "Administrator"
    Set-SecurePassword -Username "Administrator" -SecurePassword $securePassword
}
catch {
    Write-Error "Failed to configure Administrator account: $_"
}

# Check if User account exists, rename to NCR if it does, create NCR if it doesn't
try {
    $userExists = Get-LocalUser -Name "User" -ErrorAction SilentlyContinue
    if ($null -ne $userExists) {
        Rename-LocalUser -Name "User" -NewName "NCR"
        Write-Host "User account renamed to NCR successfully."
    }
    else {
        $ncrExists = Get-LocalUser -Name "NCR" -ErrorAction SilentlyContinue
        if ($null -eq $ncrExists) {
            New-LocalUser -Name "NCR" -Password $securePassword -FullName "NCR" -Description "Standard User Account"
            Write-Host "NCR account created successfully."
        }
        else {
            Write-Host "NCR account already exists."
        }
    }
    
    Enable-LocalUser -Name "NCR"
    Set-SecurePassword -Username "NCR" -SecurePassword $securePassword
    
    $isMember = Get-LocalGroupMember -Group "Administrators" | Where-Object { $_.Name -like "*\NCR" }
    if ($null -eq $isMember) {
        Add-LocalGroupMember -Group "Administrators" -Member "NCR"
        Write-Host "NCR has been added to the Administrators group."
    } else {
        Write-Host "NCR is already a member of the Administrators group."
    }
}
catch {
    Write-Error "Failed to configure NCR account: $_"
}

# Return to the original directory
Pop-Location

Write-Host "Configuration completed successfully. All tasks finished without errors."

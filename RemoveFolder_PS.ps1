Clear-Host

# Function to check hostname suffix using regex
function Test-HostnameSuffix {
    $hostname = $env:COMPUTERNAME
    Write-Host "Hostname: $hostname" -ForegroundColor Cyan
    
    # Extract the last three characters
    $lastThreeDigits = $hostname.Substring($hostname.Length - 3)
    Write-Host "Extracted last three characters: $lastThreeDigits" -ForegroundColor Cyan

    $suffixes = @("200", "201", "137", "138", "139")
    $prefixesToExclude = @("MHM", "LCD", "LCDQ", "CNC", "MKS")
    $prefixesToCheckSuffix = @("WKS")

    # Check if hostname starts with any of the prefixes to exclude
    foreach ($prefix in $prefixesToExclude) {
        if ($hostname.StartsWith($prefix)) {
            Write-Host "Hostname starts with excluded prefix: $prefix. Exiting with code 7." -ForegroundColor Yellow
            return $true
        }
    }

    # Check if hostname starts with any of the prefixes to check suffix
    foreach ($prefix in $prefixesToCheckSuffix) {
        if ($hostname.StartsWith($prefix)) {
            # Check if the last three digits match any in the suffixes array
            if ($suffixes -contains $lastThreeDigits) {
                Write-Host "Match found in suffixes array for hostname starting with $prefix : $lastThreeDigits" -ForegroundColor Yellow
                return $true
            }
        }
    }

    Write-Host "No issues with hostname, continue with script execution." -ForegroundColor Green
    return $false
}

# Function to check if running as Administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check for Administrator privileges
if (-not (Test-Admin)) {
    Write-Host "This script must be run as an Administrator." -ForegroundColor Red
    exit
}

# Check if hostname is WLPOSSRV888 (case insensitive)
if ($env:COMPUTERNAME -ieq "WLPOSSRV888") {
    Write-Host "Hostname is WLPOSSRV888. Exiting with code 0." -ForegroundColor Yellow
    exit 0
}

# Check the hostname suffix
if (Test-HostnameSuffix) {
    Write-Host "Hostname ends with specified suffix or starts with excluded prefix. Exiting with code 7." -ForegroundColor Yellow
    exit 7
}

Write-Host "Script is running with Administrator privileges." -ForegroundColor Green

# Function to check and delete folder if it exists
function Remove-Folder {
    param (
        [string]$folderPath
    )

    if (Test-Path $folderPath) {
        try {
            Remove-Item -Path $folderPath -Recurse -Force
            Write-Output "Folder $folderPath and its contents have been deleted successfully."
        } catch {
            Write-Error "An error occurred while deleting $folderPath : $_"
        }
    } else {
        Write-Output "The folder $folderPath does not exist."
    }
}

# Check and delete folders
Remove-Folder -folderPath "C:\PS"
Remove-Folder -folderPath "D:\ivantishare\PS"

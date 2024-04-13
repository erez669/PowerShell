Clear-Host

# Define the function Compare-VersionParts at the beginning of the script
function Compare-VersionParts {
    param([string]$version1, [string]$version2)
    $v1Parts = $version1 -split '\.'
    $v2Parts = $version2 -split '\.'

    # Check if there are at least two parts for both versions
    if ($v1Parts.Count -lt 2 -or $v2Parts.Count -lt 2) {
        return $false
    }
    
    # Compare the major and minor version numbers
    return ($v1Parts[0] -eq $v2Parts[0]) -and ($v1Parts[1] -eq $v2Parts[1])
}

# Function to check if the server is available using Ping
function Test-ServerAvailability {
    param([string]$ServerName)
    $ping = New-Object System.Net.NetworkInformation.Ping
    try {
        $reply = $ping.Send($ServerName, 1000)
        return $reply.Status -eq 'Success'
    } catch {
        return $false
    }
}

# Function to check the version from a file path
function CheckRemoteVersion {
    param($path)
    if (Test-Path $path) {
        try {
            $content = Get-Content $path -ErrorAction SilentlyContinue
            if ($content -match "(\d+\.\d+)") {
                return $Matches[1]
            }
        } catch {
            Write-Host "Error reading the file at path: $path"
        }
    }
    return $false
}

# Get the hostname and system architecture
$hostname = $env:COMPUTERNAME
if ($hostname -match '^POS-(\d{3})') {
    $num = $Matches[1]
    Write-Host "Hostname: $hostname"
    Write-Host "Extracted snif number: $num"
} else {
    Write-Host "Hostname ($hostname) does not start with 'POS' followed by a 3-digit number. Exiting script."
    exit 7
}

$architecture = if ([System.IntPtr]::Size -eq 8) { "x64" } else { "x86" }
Write-Host "System architecture: $architecture"

# Define server file paths
$plpossrvPath = "\\plpossrv$num\d$\Retalix\FPStore\WSGpos\version.txt"
$slpossrvPath = "\\slpossrv$num\d$\Retalix\FPStore\WSGpos\version.txt"

# Get the expected version
$expectedVersion = $args[0]
if (-not $expectedVersion) {
    Write-Host "No expected version number provided. Exiting script."
    exit 4
}

# Check PLPOSSRV version
$plServerVersion = CheckRemoteVersion $plpossrvPath

# Check SLPOSSRV version if the server is available
$slServerAvailable = Test-ServerAvailability -ServerName ($slpossrvPath -split '\\')[2]
$slServerVersion = if ($slServerAvailable) { CheckRemoteVersion $slpossrvPath } else { "Unavailable" }

# Determine local application path
$localPath = $null
if ($hostname -match "^POS-\d{3}-\d{2}-SCO$") {
    $localPath = "C:\Program Files\Retalix\SCO.NET\App\SCO.exe"
    if ($architecture -eq "x64") {
        $localPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\SCO.exe"
    }
} elseif ($hostname -match "^POS-\d{3}-\d{2}-CSS$") {
    $localPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\SCO.exe"
} else {
    $localPath = "C:\retalix\wingpos\GroceryWinPos.exe"
}

# Check local POS version
$posVersion = $false
if ($localPath -and (Test-Path $localPath)) {
    $fileVersionInfo = (Get-Item $localPath).VersionInfo
    $posVersion = $false
if ($fileVersionInfo.FileVersion -match "(\d+\.\d+\S*)") {
    $posVersion = $Matches[1]
}
}

# Output results
Write-Host "Expected POS Version: $expectedVersion"
Write-Host "PLPOSSRV current Version: $plServerVersion"
Write-Host "SLPOSSRV current Version: $slServerVersion"
Write-Host "POS Version (actual): $posVersion"

# Version comparison and final decision
$plVersionMatch = Compare-VersionParts $plServerVersion $expectedVersion
$posVersionMatch = Compare-VersionParts $posVersion $expectedVersion

# First, check if the SL server version is "Unavailable", then no need to compare versions
$slVersionMatch = $false
if ($slServerVersion -eq "Unavailable") {
    $slVersionMatch = $true
} else {
    $slVersionMatch = Compare-VersionParts $slServerVersion $expectedVersion
}

if ($plVersionMatch -and $slVersionMatch) {
    Write-Host "Server version is OK, continue with POS installation."
    exit 0
} else {
    Write-Host "Version mismatch was detected, please check your servers before continue installing pos device."
    exit 8
}

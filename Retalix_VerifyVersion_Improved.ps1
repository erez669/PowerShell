Clear-Host

# Define the function Compare-VersionParts at the beginning of the script
function Compare-VersionParts {
    param([string]$version1, [string]$version2)
    $v1Parts = $version1 -split '\.'
    $v2Parts = $version2 -split '\.'

    # Only compare the first three parts, if they exist
    $v1Parts = $v1Parts[0..([Math]::Min(2, $v1Parts.Length-1))]
    $v2Parts = $v2Parts[0..([Math]::Min(2, $v2Parts.Length-1))]

    # Ensure both versions have the same number of parts for comparison
    while ($v1Parts.Count -lt $v2Parts.Count) {
        $v1Parts += "0"
    }
    while ($v2Parts.Count -lt $v1Parts.Count) {
        $v2Parts += "0"
    }

    for ($i = 0; $i -lt $v1Parts.Count; $i++) {
        if ([int]$v1Parts[$i] -ne [int]$v2Parts[$i]) {
            Write-Host "Mismatch at part $i : $version1 vs $version2"
            return $false
        }
    }
    return $true
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
            if ($content -match "(\d+\.\d+(\.\d+)*)") {
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
    $productVersion = $fileVersionInfo.ProductVersion
    if ($productVersion -match "(\d+\.\d+(\.\d+)*)") {
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
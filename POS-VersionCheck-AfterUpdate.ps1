Clear-Host

# Function to compare the first three parts of the version numbers
function Compare-VersionParts {
    param([string]$version1, [string]$version2)
    $v1Parts = $version1 -split '\.'
    $v2Parts = $version2 -split '\.'

    # Only compare the first three parts
    $v1Parts = $v1Parts[0..2]
    $v2Parts = $v2Parts[0..2]

    # Ensure both versions have the same number of parts for comparison
    while ($v1Parts.Count -lt $v2Parts.Count) {
        $v1Parts += "0"
    }
    while ($v2Parts.Count -lt $v1Parts.Count) {
        $v2Parts += "0"
    }

    for ($i = 0; $i -lt $v1Parts.Count; $i++) {
        if ([int]$v1Parts[$i] -ne [int]$v2Parts[$i]) {
            return $false
        }
    }
    return $true
}

# Get the hostname
$hostname = $env:COMPUTERNAME

# Proceed only if hostname starts with "POS"
if ($hostname -like "POS*") {
    # Determine system architecture
    $architecture = "x86"
    if ([Environment]::Is64BitOperatingSystem) {
        $architecture = "x64"
    }

    # Define regex pattern for suffixes
    $patternSuffix = "^POS-\d{3}-\d{2}-(\w{3})$"
    $patternWithoutSuffix = "^POS-\d{3}-\d{2}$"

    # Initialize paths
    $paths = @()

    # Check hostname pattern and set path accordingly
    if ($hostname -match $patternSuffix) {
        # Capture the suffix
        $suffix = $matches[1]

        # Set paths based on the device type and architecture
        switch ($suffix) {
            "SCO" {
                # Set path for SCO devices
                if ($architecture -eq "x64") {
                    $paths += "C:\Program Files (x86)\Retalix\SCO.NET\App\SCO.exe"
                } else {
                    $paths += "C:\Program Files\Retalix\SCO.NET\App\SCO.exe"
                }
                break
            }
            "CSS" {
                # Set path for CSS devices
                $paths += "C:\Program Files (x86)\Retalix\SCO.NET\App\SCO.exe"
                break
            }
            default {
                # Set default path for other suffixes including PHR
                $paths += "C:\retalix\wingpos\GroceryWinPos.exe"
                break
            }
        }
    }
    elseif ($hostname -match $patternWithoutSuffix) {
        # Set path for devices without suffix
        $paths += "C:\retalix\wingpos\GroceryWinPos.exe"
    }
    else {
        # Unknown device pattern
        Write-Host "Unknown device pattern: $hostname"
        exit 4
    }

    # Expected version
    $expectedVersion = $args[0]

    # Loop through each path
    foreach ($path in $paths) {
        # Output path being checked
        Write-Host "Checking path: $path"  

        if (Test-Path $path) {
            # Get full version string
            $fullVersion = (Get-Item $path).VersionInfo.ProductVersion

            # Compare only the first three parts of the version
            if (-not (Compare-VersionParts $fullVersion $expectedVersion)) {
                Write-Host "Incorrect version found at $path : $fullVersion"
                exit 6 
            } else {
                Write-Host "Correct version $expectedVersion found at $path"
                exit 0
            }
        } else {
            # Output if file not found
            Write-Host "File not found at path: $path" 
        }
    }

    # If no paths were found
    if (-not $paths) {
        Write-Host "No executable path found for device type $suffix"
        exit 4
    }
} else {
    # Hostname does not start with "POS", script ends without further action
    Write-Host "Hostname does not start with 'POS', exiting script."
    exit 0
}

Clear-Host

# Define the device type based on the hostname
$deviceType = if ($env:COMPUTERNAME -like "*CSS*") {
    "CSS"
} elseif ($env:COMPUTERNAME -like "*SCO*") {
    "SCO"
} else {
    "Other"
}

# Define dynamic base path depending on the device type and architecture
$basePath = switch ($deviceType) {
    "CSS" { "C:\Program Files (x86)\Retalix" }  # CSS devices always use this path
    "SCO" {
        if ([Environment]::Is64BitOperatingSystem) {
            "C:\Program Files (x86)\Retalix"  # SCO devices on a 64-bit system use the 32-bit app path
        } else {
            "C:\Program Files\Retalix"  # SCO devices on a 32-bit system use the standard path
        }
    }
    "Other" { "C:\retalix\wingpos" }  # Default path for non-CSS and non-SCO devices
}

# Define an array of file paths using the base path
$paths = @()
if (-not ($env:COMPUTERNAME -match '^POS-')) {
    $paths += "D:\retalix\FPStore\WSGpos\version.txt"
}

if ($env:COMPUTERNAME -match '^POS-(\d+)(?:-|$)') {
    $num = $Matches[1]
    $localPath = "$basePath\SCO.NET\App\version.txt"  # Common structure for CSS and SCO
    if ($deviceType -eq "Other") {
        $localPath = "C:\retalix\wingpos\version.txt"  # Specific structure for other devices
    }
    $remotePath = "\\plpossrv$num\d$\retalix\FPStore\WSGpos\version.txt"
    $paths += $localPath, $remotePath
    Write-Host "Paths added: $localPath, $remotePath"
}

# Define the registry key path
$registryPath = "HKLM:\SOFTWARE\Retalix\Version"

# Ensure the registry path exists
if (-not (Test-Path $registryPath)) {
    try {
        New-Item -Path $registryPath -Force
    } catch {
        Write-Host "Failed to create registry path: $_"
    }
}

# Loop through each file path in the array
foreach ($path in $paths) {
    Write-Host "Checking path: $path"
    if (Test-Path $path) {
        $content = Get-Content -Path $path -ErrorAction SilentlyContinue
        if ($null -ne $content -and $content -match "(\d+(\.\d+)*(_\d+)+)") {
            Write-Host "File: $path"
            Write-Host "Matched Pattern: $($Matches[1])"

            $propertyName = if ($path -eq $remotePath) { "Server Version" } else { "Version Number" }
            try {
                New-ItemProperty -Path $registryPath -Name $propertyName -Value $Matches[1] -PropertyType String -Force
            } catch {
                Write-Host "Failed to set registry property: $_"
            }

            if ($path -eq $remotePath) {
                $destination = if ($env:COMPUTERNAME -like "*SCO*") {
                    "$basePath\SCO.NET\App\VersionServer.txt"
                } elseif ($env:COMPUTERNAME -like "*CSS*") {
                    "$basePath\SCO.NET\App\VersionServer.txt"
                } else {
                    "C:\retalix\wingpos\VersionServer.txt"
                }
                try {
                    Copy-Item -Path $path -Destination $destination -Force
                    Write-Host "File copied to local path: $destination"
                } catch {
                    Write-Host "Failed to copy file: $_"
                }
            }
        } else {
            Write-Host "No version pattern matched in file at $path"
        }
    } else {
        Write-Host "Path not found: $path"
    }
}

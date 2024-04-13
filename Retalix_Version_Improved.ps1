Clear-Host
$ErrorActionPreference = "SilentlyContinue"

# Define an array of file paths
$paths = @(
    "D:\retalix\FPStore\WSGpos\version.txt",
    "C:\retalix\wingpos\version.txt",
    "C:\Program Files (x86)\Retalix\SCO.NET\App\version.txt",
    "C:\Program Files\Retalix\SCO.NET\App\version.txt"
)

# Define the registry key path
$registryPath = "HKLM:\SOFTWARE\Retalix\Version"

# Create the registry key if it doesn't exist
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force
}

# Loop through each file path in the array
foreach ($path in $paths) {
    # Read the content of the file
    $content = Get-Content -Path $path

    # Match the pattern using the -match operator and a regex
    if ($content -match "(\d+(\.\d+)*(_\d+)+)") {
        # Output the file path and the matched pattern
        Write-Host "File: $path"
        Write-Host "Matched Pattern: $($Matches[1])"
        Write-Host "" # Empty line for better readability

        # Set the "version number" registry value to the matched pattern
        New-ItemProperty -Path $registryPath -Name "Version Number" -Value $Matches[1] -PropertyType String -Force
    }
}
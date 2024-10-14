# Clear the console
Clear-Host

# Define the list of required Visual C++ Redistributable components
$requiredComponents = @(
    'Microsoft Visual C++ 2005 Redistributable',
    'Microsoft Visual C++ 2005 Redistributable (x64)',
    'Microsoft Visual C++ 2008 Redistributable - x64 9.0.30729.6161',
    'Microsoft Visual C++ 2008 Redistributable - x86 9.0.30729.6161',
    'Microsoft Visual C++ 2010 x64 Redistributable - 10.0.40219',
    'Microsoft Visual C++ 2010 x86 Redistributable - 10.0.40219',
    'Microsoft Visual C++ 2012 Redistributable (x64) - 11.0.61030',
    'Microsoft Visual C++ 2012 Redistributable (x86) - 11.0.61030',
    'Microsoft Visual C++ 2013 Redistributable (x64) - 12.0.40664',
    'Microsoft Visual C++ 2013 Redistributable (x86) - 12.0.40664',
    'Microsoft Visual C++ 2015-2022 Redistributable (x64) - 14.40.33810',
    'Microsoft Visual C++ 2015-2022 Redistributable (x86) - 14.40.33810'
)

# Registry paths to check for installed applications
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# List to store detected components
$installedComponents = @()

# Search for installed Visual C++ Redistributable components
foreach ($path in $registryPaths) {
    $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "Microsoft Visual C++*Redistributable*" }
    foreach ($item in $items) {
        $installedComponents += [PSCustomObject]@{
            DisplayName = $item.DisplayName
            Version     = $item.DisplayVersion
            Publisher   = $item.Publisher
        }
    }
}

# Display installed components
if ($installedComponents.Count -gt 0) {
    Write-Host "Installed Microsoft Visual C++ Redistributable components:" -ForegroundColor Cyan
    $installedComponents | Sort-Object DisplayName | Format-Table -AutoSize
} else {
    Write-Host "No Microsoft Visual C++ Redistributable components found." -ForegroundColor Red
}

# Check for missing components using regex to handle minor discrepancies in naming
$missingComponents = @()
foreach ($requiredComponent in $requiredComponents) {
    # Convert the required component name into a more flexible regex
    $regexPattern = [regex]::Escape($requiredComponent).Replace('\ ', '\s*') # Allow multiple spaces in place of single spaces
    $matchFound = $installedComponents | Where-Object { $_.DisplayName -match $regexPattern }

    if (-not $matchFound) {
        Write-Host "No match found for: $requiredComponent" -ForegroundColor Red
        $missingComponents += $requiredComponent
    } else {
        Write-Host "Match found for: $requiredComponent" -ForegroundColor Green
    }
}

# Display missing components and install if necessary
if ($missingComponents.Count -gt 0) {
    Write-Host "`nThe following components are missing:" -ForegroundColor Yellow
    foreach ($missingComponent in $missingComponents) {
        Write-Host $missingComponent -ForegroundColor Red
    }

    # Run the installation file from the script's root directory
    $installerPath = Join-Path -Path $PSScriptRoot -ChildPath "Visual_C_Runtimes.exe"
    if (Test-Path -Path $installerPath) {
        Write-Host "`nStarting the installation of missing components..." -ForegroundColor Cyan
        Start-Process -FilePath $installerPath -Wait
        Write-Host "Installation complete." -ForegroundColor Green
    } else {
        Write-Host "`nInstaller file not found at: $installerPath. Please verify the location of 'Visual_C_Runtimes.exe'." -ForegroundColor Red
    }
} else {
    Write-Host "`nAll required Microsoft Visual C++ Redistributable components are installed." -ForegroundColor Green
}
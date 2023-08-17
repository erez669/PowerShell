Clear-Host

# Get the hostname
$hostname = $env:COMPUTERNAME

# Determine system architecture
$architecture = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }

# Check if the hostname matches the pattern POS-XXX-XX-SCO
if ($hostname -match "^POS-\d{3}-\d{2}-SCO$") {
  # Set path for SCO devices
  if ($architecture -eq "x64") {
    $paths = @(
      "C:\Program Files (x86)\Retalix\SCO.NET\App\SCO.exe"
    )
  }
  else {
    $paths = @(
      "C:\Program Files\Retalix\SCO.NET\App\SCO.exe"
    )
  }
}
# Check if the hostname matches the pattern POS-XXX-XX-CSS
elseif ($hostname -match "^POS-\d{3}-\d{2}-CSS$") {
  # Set path for CSS devices
  $paths = @(
    "C:\Program Files (x86)\Retalix\SCO.NET\App\SCO.exe"
  )
}
# Check if the hostname matches the pattern POS-XXX-XX
elseif ($hostname -match "^POS-\d{3}-\d{2}$") {
  # Set path for other POS devices
  $paths = @(
    "C:\retalix\wingpos\GroceryWinPos.exe"
  )
}
else {
  # Set default path or handle error
  Write-Host "Unknown device type: $hostname"
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
    $fullVersion = (Get-Item $path).VersionInfo.FileVersion

    # Check major/minor parts match expected
    if ($fullVersion -notmatch "^$expectedVersion") {
      Write-Host "Incorrect version $fullVersion found at $path"
      exit 6 
    }
    else {
      Write-Host "Correct version $expectedVersion found at $path"
      exit 0
    }

  }
  else {
    # Output if file not found
    Write-Host "File not found at path: $path" 
  }

}

# If no match, no file was found
Write-Host "File not found in paths"
exit 4

# Get the folder path of this script 
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

Clear-Host

# Check if platform is x64
if ([System.Environment]::Is64BitOperatingSystem) {

  # Platform is x64, launch x64 exe as admin
  $exePath = Join-Path $scriptPath "SDI_x64_R2309.exe"  
  $process = New-Object System.Diagnostics.Process
  $process.StartInfo.FileName = $exePath
  $process.StartInfo.Verb = "runas"

  # Try to start, catch cancellation error
  try {
    $process.Start() 
  }
  catch [System.ComponentModel.Win32Exception] {
    if ($_.Exception.Message -eq "The operation was canceled by the user") {
      Write-Host "The operation was canceled by user"
    }
    else {
      Write-Host $_.Exception.Message
    }
  }

}

else {

  # Platform is not x64, launch x86 exe as admin
  $exePath = Join-Path $scriptPath "SDI_R2309.exe"
  $process = New-Object System.Diagnostics.Process
  $process.StartInfo.FileName = $exePath
  $process.StartInfo.Verb = "runas"
  
# Try to start, catch cancellation error
  try {
    $process.Start()
  }
  catch [System.ComponentModel.Win32Exception] {
    if ($_.Exception.Message -eq "The operation was canceled by the user") {
      Write-Host "The operation was canceled by user" 
    }
    else {
      Write-Host $_.Exception.Message
    }
  }

}
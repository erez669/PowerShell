# Set verbose preference
$VerbosePreference = 'Continue'

# Output file paths
$outputFile1 = "C:\Install\RunAll_Servers_output.txt"
$outputFile2 = "C:\Install\RunAll_Kupot_output.txt"

function Get-OSCaption {
  return (Get-WmiObject Win32_OperatingSystem).Caption 
}

# Get OS caption
$osCaption = Get-OSCaption

# Check if server OS
$isServer = $osCaption -like '*Server*'

# Arguments for server batch 
$serverArgs = "490", "670015390"
$batchArgs = "" # Initialize variable for batch arguments

# Determine batch file name
$batchFile = if ($isServer) {
  $batchArgs = $serverArgs # Set args for server
  "Run_All_Servers_D.cmd"
}
else {
  "Run_All_Kupot_C.cmd"
}

Write-Verbose "OS Caption: $osCaption"
Write-Verbose "Is Server: $isServer" 
Write-Verbose "Batch file: $batchFile"

# Write verbose messages to the correct file based on OS type
if ($isServer) {
    "OS Caption: $osCaption" | Out-File -FilePath $outputFile1 -Append
    "Is Server: $isServer" | Out-File -FilePath $outputFile1 -Append
    "Batch file: $batchFile" | Out-File -FilePath $outputFile1 -Append
    "Arguments: $batchArgs" | Out-File -FilePath $outputFile1 -Append
}
else {
    "OS Caption: $osCaption" | Out-File -FilePath $outputFile2 -Append
    "Is Server: $isServer" | Out-File -FilePath $outputFile2 -Append
    "Batch file: $batchFile" | Out-File -FilePath $outputFile2 -Append
}

# Get the path of the script
$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Call batch file with appropriate args
if ($isServer) {
   cmd /c "$scriptPath\$batchFile $batchArgs" 2>&1 | Out-File -FilePath $outputFile1 -Append # Pass args for server
}
else {
   cmd /c "$scriptPath\$batchFile" 2>&1 | Out-File -FilePath $outputFile2 -Append # No args for non-server
}

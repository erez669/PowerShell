# Check to see if we are currently running "as Administrator"
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
    # Relaunch as an elevated process:
    Start-Process powershell.exe "-File",('"{0}"' -f $MyInvocation.MyCommand.Definition) -Verb RunAs
    exit
}

# Extract part of the hostname
$hostname = gc env:computername
$snif = $hostname.Split('-')[1]

# Define the path to the CSV file
$csvPath = "\\ivantiappsrv\IvantiShare\Packages\WKS\shufersal_selfservice\Snif_Format.csv"

# Read the CSV file
$csvData = Import-Csv $csvPath

# Initialize libraryPath
$libraryPath = $null

# Define the path to your INI file
$iniFilePath = "d:\shufersal_selfservice\config.ini"

# Finding the line containing 'ScaleID' and extracting the value of ScaleID
$scaleID = ((Get-Content $iniFilePath) -match "ScaleID")[0].Split('=')[1].Trim()

# Parse the numeric part of ScaleID
$scaleID = [int]($scaleID -replace '\D')  # '\D' matches any non-digit character

# Lookup libraryPath by snif
$row = $csvData | Where-Object { $_.Snif -eq $snif }
$code = $row.Code
$libraryPath = $row.Library

# based on the ScaleID value, perform the necessary actions
if ($scaleID -ge 20 -and $scaleID -le 21) {
    # Copy the files and call the batch file
    Copy-Item -Path "\\ivantiappsrv\IvantiShare\Packages\WKS\shufersal_selfservice\$libraryPath\20.17a_GREEN_20-21" -Destination "C:\Install\$libraryPath\20.17a_GREEN_20-21" -Recurse -Force
    & "C:\Install\${libraryPath}\20.17a_GREEN_20-21\20.17a_GREEN.bat"
}
elseif ($scaleID -eq 22) {
    Copy-Item -Path "\\ivantiappsrv\IvantiShare\Packages\WKS\shufersal_selfservice\$libraryPath\20.17a_MAFIT_22" -Destination "C:\Install\$libraryPath\20.17a_MAFIT_22" -Recurse -Force
    & "C:\Install\${libraryPath}\20.17a_MAFIT_22\20.17a_MAFIT.bat"
}
elseif ($scaleID -ge 23 -and $scaleID -le 30) {
    Copy-Item -Path "\\ivantiappsrv\IvantiShare\Packages\WKS\shufersal_selfservice\$libraryPath\20.17a_YARAP_23-30" -Destination "C:\Install\$libraryPath\20.17a_YARAP_23-30" -Recurse -Force
    & "C:\Install\${libraryPath}\20.17a_YARAP_23-30\20.17a_YARAP.bat"
}
elseif ($scaleID -ge 41 -and $scaleID -le 43) {
    Copy-Item -Path "\\ivantiappsrv\IvantiShare\Packages\WKS\shufersal_selfservice\${libraryPath}\20.17a_KULINARIT_41-43" -Destination "C:\Install\${libraryPath}\20.17a_KULINARIT_41-43" -Recurse -Force
    & "C:\Install\${libraryPath}\20.17a_KULINARIT_41-43\20.17a_KULINARIT.bat"
}
else {
    Write-Host "Scale Number is Wrong, Please Report to AsafM"
    Exit 10
}
# Extract Event Viewer Logs v2.1
# PowerShell script to export event logs from Event Viewer to a folder named "EventViewerExport" on the Desktop
# Made by Shomron Joseph David - Dangot
# LinkedIn: https://www.linkedin.com/in/shomrondavid/
# Tested on Windows Server 2012 R2 - Windows 10 - Windows 11 - Windows Server 2019 - Windows Server 2022

$ExportPath = "$env:USERPROFILE\Desktop\EventViewerExport"
$ShowErrors = $false # Set to $true to display errors, or $false to suppress errors

# Create the export folder if it doesn't exist
if (!(Test-Path $ExportPath)) {
    New-Item -ItemType Directory -Path $ExportPath -ErrorAction SilentlyContinue | Out-Null
}

# Get a list of all event logs
$EventLogs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue

# Display the list of available event logs
Write-Host "Available event logs:"
foreach ($Log in $EventLogs) {
    Write-Host "- $($Log.LogName)"
}

# Prompt the user to select which logs they want to export
# basic includes Application, Security, Setup, System, ForwardedEvents

$SelectedLogs = Read-Host "Enter a comma-separated list of log names to export or type 'basic', or type 'all' to export all logs"

if ($SelectedLogs.ToLower() -eq "all") {
    $SelectedLogsArray = $EventLogs.LogName
} elseif ($SelectedLogs.ToLower() -eq "basic") {
    $SelectedLogsArray = @("Application", "Security", "Setup", "System", "ForwardedEvents")
} else {
    $SelectedLogsArray = $SelectedLogs -split "," | ForEach-Object { $_.Trim() }
}

# Export the selected event logs to the export folder
$TotalLogs = $SelectedLogsArray.Count
$ExportedLogs = 0
foreach ($Log in $SelectedLogsArray) {
    $EventLog = $EventLogs | Where-Object {$_.LogName -eq $Log}
    if ($EventLog) {
        $LogName = $EventLog.LogName
        $ExportFile = Join-Path $ExportPath "$LogName.evtx"
        $ProgressStatus = "Exporting $LogName - $ExportedLogs of $TotalLogs logs exported"
        Write-Progress -Activity "Exporting event logs" -Status $ProgressStatus -PercentComplete (($ExportedLogs / $TotalLogs) * 100)

        # Export the event log to a file
        Get-WinEvent -LogName $LogName -ErrorAction SilentlyContinue | Export-Clixml -Path $ExportFile -ErrorAction SilentlyContinue

        $ExportedLogs++
    } else {
        if ($ShowErrors) {
            Write-Warning "The '$Log' event log could not be found."
        }
    }
}

# Update the progress bar to show completion
Write-Progress -Activity "Exporting event logs" -Status "Export completed" -PercentComplete 100

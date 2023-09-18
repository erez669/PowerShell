# Log file path
$logFile = "C:\Install\PolicySync_log.txt"

function Write-Log {
    Param ([string]$message)  
    try {
        Add-Content $logFile -Value "$(Get-Date) - $message"
    }
    catch {
        Write-Host "Couldn't write to log: $_"
    }
}

# Automatically relaunch as admin if not already
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Log "Not running as administrator. Relaunching as admin..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path)
    exit
}

$TaskScheduler = New-Object -ComObject "Schedule.Service"
$TaskScheduler.Connect()
$RootFolder = $TaskScheduler.GetFolder("\")
$TaskName = "LANDESK PolicySync"

# Check if the task exists
try {
    $ExistingTask = $RootFolder.GetTask($TaskName)
    if ($ExistingTask) {
        Write-Log "Task '$TaskName' already exists. Deleting..."
        $RootFolder.DeleteTask($TaskName, 0)
    }
}
catch {
    Write-Log "Task '$TaskName' does not exist."
}

$TaskDefinition = $TaskScheduler.NewTask(0)
$Action = $TaskDefinition.Actions.Create(0)

$arch = [System.Environment]::Is64BitOperatingSystem
$Action.Path = if ($arch) { 'C:\Program Files (x86)\LANDesk\LDClient\PolicySync.exe' } else { 'C:\Program Files\LANDesk\LDClient\PolicySync.exe' }

$TaskDefinition.Principal.RunLevel = 1 # Highest privileges
$Trigger = $TaskDefinition.Triggers.Create(1)  # Time trigger
$StartTime = (Get-Date).AddDays(1).Date.AddHours(2)  # Starts at 2 AM tomorrow
$Trigger.StartBoundary = $StartTime.ToString("yyyy-MM-ddTHH:mm:ss")
$Trigger.Repetition.Interval = "PT2H"  # Interval is 2 hours
$Trigger.Enabled = $true
$Settings = $TaskDefinition.Settings
$Settings.AllowDemandStart = $true
$Settings.DisallowStartIfOnBatteries = $false
$Settings.StopIfGoingOnBatteries = $false
$Settings.WakeToRun = $true
$Settings.ExecutionTimeLimit = "PT0S"
$Settings.StartWhenAvailable = $true

# Register the task
$RootFolder.RegisterTaskDefinition($TaskName, $TaskDefinition, 6, "NT AUTHORITY\SYSTEM", $null, 5)

Write-Log "Task '$TaskName' created successfully."

# Close the log file
Write-Log "Script finished"

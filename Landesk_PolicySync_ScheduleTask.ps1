# Automatically relaunch as admin if not already
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path)
    exit
}

$TaskScheduler = New-Object -ComObject "Schedule.Service"
$TaskScheduler.Connect()
$RootFolder = $TaskScheduler.GetFolder("\")
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

$RootFolder.RegisterTaskDefinition("LANDESK PolicySync", $TaskDefinition, 6, "NT AUTHORITY\SYSTEM", $null, 5)

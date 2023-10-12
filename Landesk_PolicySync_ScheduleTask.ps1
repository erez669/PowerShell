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

If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

Clear-Host

$VerbosePreference = 'Continue'

$taskName = "LANDesk_PolicySync_Workaround"

$taskService = New-Object -ComObject Schedule.Service
$taskService.Connect($env:COMPUTERNAME)

$rootFolder = $taskService.GetFolder("\")
$existingTasks = $rootFolder.GetTasks(0)

# If the old task exists, delete it
$oldTask = $existingTasks | Where-Object { $_.Name -eq $taskName }
if ($oldTask) {
    $rootFolder.DeleteTask("\$taskName", 0)
}

$taskDefinition = $taskService.NewTask(0)

$action = $taskDefinition.Actions.Create(0)
$action.Path = "C:\Windows\System32\cmd.exe"
$action.Arguments = '/C start /min powershell.exe -File "\\HDTOOLSSRV\pos\LandeskPolicy_Sync_Workaround.ps1"'

$triggers = $taskDefinition.Triggers
$trigger = $triggers.Create(1)
$trigger.StartBoundary = (Get-Date).AddDays(1).ToString('yyyy-MM-dd') + 'T00:00:00'
$trigger.Repetition.Interval = 'PT6H'

$principal = $taskDefinition.Principal
$principal.GroupId = 'S-1-5-18'
$principal.RunLevel = 1

$settings = $taskDefinition.Settings
$settings.DisallowStartIfOnBatteries = $false
$settings.StartWhenAvailable = $true
$settings.WakeToRun = $true
$settings.ExecutionTimeLimit = 'PT0S'

$rootFolder.RegisterTaskDefinition($taskName, $taskDefinition, 6, $null, $null, 3)

Write-Log "Task '$TaskName' created successfully."

# Close the log file
Write-Log "Script finished"

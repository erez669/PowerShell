$TaskScheduler = New-Object -ComObject "Schedule.Service"
$TaskScheduler.Connect()
$RootFolder = $TaskScheduler.GetFolder("\")
$TaskDefinition = $TaskScheduler.NewTask($null)
$Action = $TaskDefinition.Actions.Create(0)
$Action.Path = "shutdown.exe"
$Action.Arguments = "-r -t 0 -f"
$Action.WorkingDirectory = "C:\Windows\System32"
$TaskDefinition.Principal.RunLevel = 1 # Highest privileges
$Trigger = $TaskDefinition.Triggers.Create(1) # time trigger
$StartTime = [DateTime]::Today.AddDays(1).AddHours(2)
$Trigger.StartBoundary = $StartTime.ToString("yyyy-MM-ddTHH:mm:ss")
$Trigger.Enabled = $True
$Settings = $TaskDefinition.Settings
$Settings.AllowDemandStart = $True
$Settings.DisallowStartIfOnBatteries = $False
$Settings.StopIfGoingOnBatteries = $False
$Settings.WakeToRun = $True
$Settings.ExecutionTimeLimit = "PT0S"
$Settings.StartWhenAvailable = $True
$RootFolder.RegisterTaskDefinition("Reboot", $TaskDefinition, 6, "NT AUTHORITY\SYSTEM", $null, 5, $null)

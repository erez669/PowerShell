                                #Written By Erez Schwartz 15.5.23

Clear-Host

# Define the executable path based on the architecture
if ([IntPtr]::Size -eq 4) {
    $executable = "C:\Program Files\LANDesk\LDClient\LDISCN32.EXE"
} else {
    $executable = "C:\Program Files (x86)\LANDesk\LDClient\LDISCN32.EXE"
}

# Create the Task Scheduler COM object
$scheduler = New-Object -ComObject Schedule.Service
$scheduler.Connect()

# Get the root folder
$rootFolder = $scheduler.GetFolder("\") 

# Create the task definition
$taskDefinition = $scheduler.NewTask(0)
$taskDefinition.RegistrationInfo.Description = "LANDESK Inventory Scan"
$taskDefinition.Settings.Enabled = $true
$taskDefinition.Settings.StartWhenAvailable = $true # This disables the "Start the task only if the computer is on AC power" setting
$taskDefinition.Settings.DisallowStartIfOnBatteries = $false # This also disables the "Start the task only if the computer is on AC power" setting
$taskDefinition.Settings.WakeToRun = $true # This enables the "Wake the computer to run this task" setting
$taskDefinition.Settings.ExecutionTimeLimit = "PT0S" # No time limit

# Create the trigger
$trigger = $taskDefinition.Triggers.Create(2) # 2 = Daily trigger
$trigger.StartBoundary = (Get-Date).ToString("yyyy-MM-dd") + "T05:00:00" # Start at 5:00 AM
$trigger.DaysInterval = 1 # Every day

# Create the action
$action = $taskDefinition.Actions.Create(0) # 0 = Execute
$action.Path = $executable
$action.Arguments = "/F /SYNC /NOUI"

# Register the task (under the SYSTEM account, with highest privileges)
$rootFolder.RegisterTaskDefinition("Landesk Inventory Scan", $taskDefinition, 6, "SYSTEM", $null, 5) # 6 = Create or update, 5 = Run with highest privileges

# Run the Task after Creation
schtasks /run /TN "Landesk Inventory Scan"
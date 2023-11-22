If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
exit
}

Clear-Host

$VerbosePreference = 'continue'

$taskName = "Restart SQL Express"

# Check if the task already exists
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    # Unregister/remove the existing task
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Action
$action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument "-NoProfile -Command `"Restart-Service -Name 'MSSQL`$SQLEXPRESS' -Force -Verbose`""

# Trigger
$trigger = New-ScheduledTaskTrigger -Daily -At '12AM'

# Settings
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Seconds 0)

# Register the task
Register-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -TaskName $taskName -Description "Restarts the SQL Express service daily at 12:00 PM" -RunLevel Highest -User "NT AUTHORITY\SYSTEM"
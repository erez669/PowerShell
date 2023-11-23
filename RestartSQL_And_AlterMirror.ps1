# Check and prompt for running as Administrator
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}

Clear-Host

$VerbosePreference = 'continue'

# Script 1 Code
$scriptPath = $MyInvocation.MyCommand.Path
$scriptRoot = Split-Path -Path $scriptPath -Parent

# Define the paths for the .ps1 and .xml files relative to the script's location
$ps1Source = Join-Path -Path $scriptRoot -ChildPath "Alter_Mirror.ps1"
$xmlSource = Join-Path -Path $scriptRoot -ChildPath "Alter_Mirror.xml"

# Define the destination folder
$destinationFolder = "C:\Install"

# Create the destination folder if it doesn't exist
if (-not (Test-Path $destinationFolder)) {
    New-Item -Path $destinationFolder -ItemType Directory -Verbose | Out-Null
}

# Copy the .ps1 and .xml files to the destination folder
Copy-Item -Path $ps1Source -Destination $destinationFolder -Force -Verbose
Copy-Item -Path $xmlSource -Destination $destinationFolder -Force -Verbose

# Import the .xml file to create a scheduled task
$xmlDestination = Join-Path -Path $destinationFolder -ChildPath (Get-Item $xmlSource).Name
$taskName = "Alter_Mirror_Witness"

# Specify the credentials
$user = "posprod\retalix_sqlinstall"

# Define the paths for the key and encrypted password relative to the script's location
$KeyPath = Join-Path -Path $scriptRoot -ChildPath "key.txt"
$EncryptedPasswordPath = Join-Path -Path $scriptRoot -ChildPath "EncryptedPassword.txt"

# Load the key and encrypted password
$Key = Get-Content $KeyPath -Encoding Byte
$EncryptedPassword = Get-Content $EncryptedPasswordPath

# Decrypt the password
$Password = ConvertTo-SecureString -String $EncryptedPassword -Key $Key

# Convert the decrypted SecureString password to plaintext
$plaintextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))

# Import the scheduled task
schtasks /create /xml $xmlDestination /tn $taskName /ru $user /rp $plaintextPassword /F

# Script 2 Code (excluding the Admin privilege check)
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

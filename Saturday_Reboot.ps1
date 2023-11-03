If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}

# Get today's date
$VerbosePreference = 'Continue'
$today = Get-Date
Write-Host "Today: $($today.ToString('dd/MM/yyyy'))" -ForegroundColor Yellow

# Specify the source and destination paths for the .ps1 and .xml files
$ps1SourcePath = "\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\Servers_PL_SL\Maintanance\Reboot\saturday_Reboot.ps1"
$ps1DestinationPath = "C:\Install\saturday_Reboot.ps1"
$xmlSourcePath = "\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\Servers_PL_SL\Maintanance\Reboot\Reboot_Server.xml"
$xmlDestinationPath = "C:\Install\Reboot_Server.xml"

# Define the folder path
$folderPath = "C:\Install"

# Create the folder, suppressing any error output if it already exists
New-Item -Path $folderPath -ItemType Directory -ErrorAction SilentlyContinue -Verbose

# Copy the .ps1 and .xml files
Copy-Item -Path $ps1SourcePath -Destination $ps1DestinationPath -Verbose
Copy-Item -Path $xmlSourcePath -Destination $xmlDestinationPath -Verbose

# Determine the week number of the month
$weekNum = [math]::Ceiling($today.Day / 7)

# Get the hostname of the machine
$hostname = $env:COMPUTERNAME

# Check if today is Saturday
if ($today.DayOfWeek -eq 'Saturday') {
    # Determine which Saturday of the month it is and check hostname to decide whether to reboot
    switch ($weekNum) {
        1 { 
            if ($hostname -like '*PLPOSSRV*') {
                Write-Verbose "Rebooting on the first Saturday of the month"
                shutdown -r -t 0 -f
            }
        }
        2 { 
            if ($hostname -like '*SLPOSSRV*') {
                Write-Verbose "Rebooting on the second Saturday of the month"
                shutdown -r -t 0 -f
            }
        }
        3 { 
            if ($hostname -like '*WLPOSSRV*') {
                Write-Verbose "Rebooting on the third Saturday of the month"
                shutdown -r -t 0 -f
            }
        }
        default {
        function Get-LastSaturday($year, $month) {
        $firstDayOfNextMonth = Get-Date -Year $year -Month $month -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0
        $firstDayOfNextMonth = $firstDayOfNextMonth.AddMonths(1)
        $lastDayOfMonth = $firstDayOfNextMonth.AddDays(-1)

        $daysUntilSaturday = [DayOfWeek]::Saturday.value__ - $lastDayOfMonth.DayOfWeek.value__
        if ($daysUntilSaturday -lt 0) { $daysUntilSaturday += 7 }
        $lastSaturday = $lastDayOfMonth.AddDays(-$daysUntilSaturday)

        return $lastSaturday
        }

        # Calculate the last Saturday of the current month once
        $lastSaturday = Get-LastSaturday -Year $today.Year -Month $today.Month

        # Check if today is the last Saturday and the hostname pattern matches
        if ($today.Date.Equals($lastSaturday.Date) -and $hostname -like '*YARPASQL*') {
        Write-Verbose "Rebooting on the last Saturday of the month"
        shutdown -r -t 0 -f
        }
}

        }
}

schtasks /create /tn "Reboot_Server" /xml "C:\Install\Reboot_Server.xml" /F

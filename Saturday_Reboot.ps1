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
$ps1SourcePath = "\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\Servers_PL_SL\Maintanance\Reboot\Saturday_Reboot.ps1"
$ps1DestinationPath = "C:\Install\Saturday_Reboot.ps1"
$xmlSourcePath = "\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\Servers_PL_SL\Maintanance\Reboot\Reboot_Server.xml"
$xmlDestinationPath = "C:\Install\Reboot_Server.xml"

# Define the folder path
$folderPath = "C:\Install"

# Create the folder, suppressing any error output if it already exists
New-Item -Path $folderPath -ItemType Directory -ErrorAction SilentlyContinue -Verbose

# Copy the .ps1 and .xml files
Copy-Item -Path $ps1SourcePath -Destination $ps1DestinationPath -Verbose -Force
Copy-Item -Path $xmlSourcePath -Destination $xmlDestinationPath -Verbose -Force

# Determine the week number of the month
$weekNum = [math]::Ceiling($today.Day / 7)

# Get the hostname of the machine
$hostname = $env:COMPUTERNAME

function Get-LastSaturday($year, $month) {
    # Get the last day of the month
    try {
        $lastDayOfMonth = Get-Date -Year $year -Month $month -Day 1 -Hour 0 -Minute 0 -Second 0
    } catch {
        Write-Error "Error in getting date: $_"
        return
    }

    if ($lastDayOfMonth -ne $null) {
        $lastDayOfMonth = $lastDayOfMonth.AddMonths(1).AddDays(-1)

        while ($lastDayOfMonth.DayOfWeek -ne [DayOfWeek]::Saturday) {
            $lastDayOfMonth = $lastDayOfMonth.AddDays(-1)
        }
    } else {
        Write-Error "Last day of month is null"
        return
    }

    return $lastDayOfMonth
}

# Calculate the last Saturday of the current month
$lastSaturday = Get-LastSaturday -Year $today.Year -Month $today.Month

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
            Write-Verbose "Checking for the last Saturday"

            # Check if today is the last Saturday and the hostname pattern matches
            if ($today.Date -eq $lastSaturday.Date) {
                Write-Verbose "Today is the last Saturday of the month"

                if ($hostname -like '*YARPASQL*') {
                    Write-Verbose "Hostname matches. Initiating reboot."
                    shutdown -r -t 0 -f
                }
                else {
                    Write-Verbose "Hostname does not match. No reboot."
                }
            }
            else {
                Write-Verbose "Today is not the last Saturday. No reboot."
            }
        }
    }
}
else {
    Write-Verbose "Today is not Saturday. No reboot."
}

schtasks /create /tn "Reboot_Server" /xml "C:\Install\Reboot_Server.xml" /F

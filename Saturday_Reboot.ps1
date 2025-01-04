# Function to check if the script is running with administrator privileges
function Check-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-NOT $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $arguments = "& '" + $myinvocation.mycommand.definition + "'"
        Start-Process powershell -Verb runAs -ArgumentList $arguments
        exit
    }
}

Clear-Host

# Function to get the last Saturday of a given month and year
function Get-LastSaturday {
    param (
        [int]$year,
        [int]$month
    )
    try {
        $firstDay = Get-Date -Year $year -Month $month -Day 1
        $lastDayOfMonth = $firstDay.AddMonths(1).AddDays(-1)
        while ($lastDayOfMonth.DayOfWeek -ne 'Saturday') {
            $lastDayOfMonth = $lastDayOfMonth.AddDays(-1)
        }
        $dateString = $lastDayOfMonth.ToString("dd/MM/yyyy")
        Write-Host "Last Saturday of $month/$year is $dateString" -ForegroundColor Cyan
        return $lastDayOfMonth
    } catch {
        Write-Host ("Error in getting date: " + $_.Exception.Message) -ForegroundColor Red
        return $null
    }
}

# Function to check if a scheduled task exists
function Test-ScheduledTaskExists {
    param (
        [string]$TaskName
    )
    try {
        $taskInfo = schtasks /query | Select-String $TaskName
        return ($taskInfo -ne $null)
    } catch {
        Write-Host ("Error checking task: " + $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

# Function to get all Saturdays in the month
function Get-SaturdaysInMonth {
    param (
        [int]$year,
        [int]$month
    )
    $saturdays = @()
    $firstDay = Get-Date -Year $year -Month $month -Day 1
    $lastDay = $firstDay.AddMonths(1).AddDays(-1)
    $daysInMonth = $lastDay.Day
    
    for ($day = 1; $day -le $daysInMonth; $day++) {
        $currentDate = Get-Date -Year $year -Month $month -Day $day
        if ($currentDate.DayOfWeek -eq 'Saturday') {
            $saturdays += $currentDate
        }
    }
    return $saturdays
}

# Function to get the week number of a date within its month based on Saturdays
function Get-SaturdayWeekNumber {
    param (
        [DateTime]$date,
        [array]$saturdays
    )
    for ($i = 0; $i -lt $saturdays.Count; $i++) {
        if ($saturdays[$i].Date -eq $date.Date) {
            return ($i + 1)
        }
    }
    return -1
}

# Function to check if the current server belongs to the specified group
function Test-ServerGroup {
    param (
        [string]$hostname,
        [string]$groupPrefix
    )
    return $hostname -like ($groupPrefix + "*")
}

# Main script logic
Check-Administrator

# Get today's date
$today = Get-Date
Write-Host ("Today: " + $today.ToString("dd/MM/yyyy")) -ForegroundColor Yellow -BackgroundColor Black

# Define paths
$ps1SourcePath = "\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\Servers_PL_SL\Maintanance\Reboot\Saturday_Reboot.ps1"
$ps1DestinationPath = "C:\Install\Saturday_Reboot.ps1"
$xmlSourcePath = "\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\Servers_PL_SL\Maintanance\Reboot\Reboot_Server.xml"
$xmlDestinationPath = "C:\Install\Reboot_Server.xml"
$folderPath = "C:\Install"

# Create folder and copy files
if (-not (Test-Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
}
Copy-Item -Path $ps1SourcePath -Destination $ps1DestinationPath -Force
Copy-Item -Path $xmlSourcePath -Destination $xmlDestinationPath -Force

# Get all Saturdays in the current month
$saturdays = @(Get-SaturdaysInMonth -Year $today.Year -Month $today.Month)
$numSaturdays = $saturdays.Count

Write-Host "`nSaturdays this month:" -ForegroundColor Cyan
for ($i = 0; $i -lt $saturdays.Count; $i++) {
    $saturdayDate = $saturdays[$i].ToString("dd/MM/yyyy")
    $weekNum = $i + 1
    if ($weekNum -eq 1) {
        $weekLabel = "First Saturday  (PL servers)"
    } elseif ($weekNum -eq 2) {
        $weekLabel = "Second Saturday (SL servers)"
    } elseif ($weekNum -eq 3) {
        $weekLabel = "Third Saturday  (WL servers)"
    } elseif ($weekNum -eq $saturdays.Count) {
        $weekLabel = "Last Saturday   (YARPA servers)"
    } else {
        $weekLabel = "Saturday $weekNum"
    }
    Write-Host ($saturdayDate + " - " + $weekLabel) -ForegroundColor Yellow
}

Write-Host ("`nNumber of Saturdays this month: " + $numSaturdays) -ForegroundColor Green
$totalWeeks = $numSaturdays
Write-Host ("Total weeks for reboot schedule: " + $totalWeeks) -ForegroundColor Green

# Determine the week number based on the Saturdays
$weekNum = Get-SaturdayWeekNumber -date $today -saturdays $saturdays
if ($weekNum -eq -1) {
    Write-Host "Today is not a Saturday, determining fallback week number..." -ForegroundColor Yellow
    $weekNum = [math]::Ceiling($today.Day / 7)
    if ($weekNum -gt $totalWeeks) {
        $weekNum = $totalWeeks
    }
}
Write-Host ("Week number of the month: " + $weekNum) -ForegroundColor Green
Write-Host ("Week " + $weekNum + " of " + $totalWeeks) -ForegroundColor Green

# Get the hostname of the machine
$hostname = $env:COMPUTERNAME
Write-Host ("Hostname: " + $hostname) -ForegroundColor Green

# Calculate the last Saturday of the current month
$lastSaturday = Get-LastSaturday -Year $today.Year -Month $today.Month

# Determine if this server should be rebooted based on the week and hostname
$shouldReboot = $false

if ($today.DayOfWeek -eq 'Saturday') {
    if ($weekNum -eq 1) {
        $shouldReboot = Test-ServerGroup -hostname $hostname -groupPrefix "PL"
    } elseif ($weekNum -eq 2) {
        $shouldReboot = Test-ServerGroup -hostname $hostname -groupPrefix "SL"
    } elseif ($weekNum -eq 3) {
        $shouldReboot = Test-ServerGroup -hostname $hostname -groupPrefix "WL"
    } else {
        if ($today.Date -eq $lastSaturday.Date) {
            $shouldReboot = Test-ServerGroup -hostname $hostname -groupPrefix "YARPA"
        }
    }
    
    # Output the server group status
    if ($shouldReboot) {
        Write-Host "This server is scheduled for reboot today." -ForegroundColor Green
        Write-Host "Initiating reboot..." -ForegroundColor Yellow
        shutdown -r -t 0 -f
    } else {
        Write-Host "This server is not scheduled for reboot today." -ForegroundColor Cyan
    }
} else {
    Write-Host "Today is not Saturday. No reboot." -ForegroundColor Yellow
}

# Check if the scheduled task already exists and create if not
if (-not (Test-ScheduledTaskExists -TaskName "Reboot_Server")) {
    Write-Host "Creating scheduled task 'Reboot_Server'..." -ForegroundColor Cyan
    schtasks /create /tn "Reboot_Server" /xml "C:\Install\Reboot_Server.xml"
} else {
    Write-Host "Scheduled task 'Reboot_Server' already exists." -ForegroundColor Cyan
}

exit 0

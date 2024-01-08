# Storing the current ErrorActionPreference value
$TempErrAct = $ErrorActionPreference

# Adjusting ErrorActionPreference to stop on all errors
$ErrorActionPreference = "Stop"

# Getting The Current Year
$CurrentYear = (Get-Date).Year

# Using the local computer name directly
$Computer = $env:COMPUTERNAME

Try {
    # Creating a DateTime Object from Win32_LocalTime from the supplied ComputerName
    $Win32LT = Get-WmiObject -Class Win32_LocalTime -ComputerName $Computer
    # Converting the Win32_LocalTime information into a DateTime object.
    [Datetime]$LocalTime = [DateTime]::new($Win32LT.Year, $Win32LT.Month, $Win32LT.Day, $Win32LT.Hour, $Win32LT.Minute, $Win32LT.Second)
    
    # Getting the current time zone
    $TimeZone = [TimeZoneInfo]::Local

    # Checking if the time zone observes DST
    if ($TimeZone.SupportsDaylightSavingTime) {
        # Getting all DST transitions for the current year
        $AdjustmentRules = $TimeZone.GetAdjustmentRules() | Where-Object { $_.DateStart.Year -le $CurrentYear -and $_.DateEnd.Year -ge $CurrentYear }

        # Assuming there's only one rule per year for simplicity
        $DSTStartTransition = $AdjustmentRules[0].DaylightTransitionStart
        $DSTEndTransition = $AdjustmentRules[0].DaylightTransitionEnd

        # Function to calculate DST transition date
        function Get-DSTDate {
            param (
                [Parameter(Mandatory = $true)]
                [System.TimeZoneInfo+TransitionTime]$Transition,

                [Parameter(Mandatory = $true)]
                [int]$Year
            )
            $DSTDate = New-Object DateTime $Year, $Transition.Month, 1, $Transition.TimeOfDay.Hour, 0, 0
            $DSTDayOfWeek = [int]$Transition.DayOfWeek

            while ($DSTDate.DayOfWeek -ne $DSTDayOfWeek) {
                $DSTDate = $DSTDate.AddDays(1)
            }

            if ($Transition.Week -eq 5) { # "Last" week
                while ($DSTDate.AddDays(7).Month -eq $Transition.Month) {
                    $DSTDate = $DSTDate.AddDays(7)
                }
            } else {
                $DSTDate = $DSTDate.AddDays(7 * ($Transition.Week - 1))
            }
            return $DSTDate
        }

        # Calculating the start and end of DST for the current year
        $DSTStartDate = Get-DSTDate -Transition $DSTStartTransition -Year $CurrentYear
        $DSTEndDate = Get-DSTDate -Transition $DSTEndTransition -Year $CurrentYear

        # Outputting DST Information in the desired format
        $DSTInfo = [PSCustomObject]@{
        Computer      = $Computer
        CurrentTime   = $LocalTime.ToString("dd/MM/yyyy hh:mm")
        DaylightName  = $TimeZone.DaylightName
        DaylightStart = $DSTStartDate.ToString("dd/MM/yyyy hh:mm")
        DaylightEnd   = $DSTEndDate.ToString("dd/MM/yyyy hh:mm")
        }

        $DSTInfo | Format-List

    } else {
        Write-Output "The time zone does not observe Daylight Saving Time."
    }

} Catch {
    Write-Warning "An exception occurred: $($Error[0].Exception.Message)"
}

# Resetting ErrorActionPreference to its original value
$ErrorActionPreference = $TempErrAct
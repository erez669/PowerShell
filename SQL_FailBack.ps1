# Verbose output
$VerbosePreference = 'Continue' 

$today = Get-Date
$firstDay = Get-Date -Day 1 
$firstSaturday = $firstDay.AddDays((6 - $firstDay.DayOfWeek) % 7)

Write-Verbose "Today: $($today.ToString('dd/MM/yyyy'))"
Write-Verbose "First day of month: $($firstDay.ToString('dd/MM/yyyy'))"
Write-Verbose "First Saturday: $($firstSaturday.ToString('dd/MM/yyyy'))"

# $taskName = "SQL_FailBack"

# Check if task already exists
# $taskExists = Invoke-Expression "schtasks /Query /TN $taskName 2>&1"

# if ($taskExists -like "*The system cannot find the file specified*") {
    # Invoke-Expression 'schtasks /create /xml "C:\install\SQL_FailBack.xml" /tn "SQL_FailBack" /ru "posprod\retalix_sqlinstall" /rp "mypass"'
# } else {
    # Write-Verbose "The task $taskName already exists"
# }

if ($today.DayOfWeek -eq 'Saturday' -and $today.Day -le $firstSaturday.Day) {

  Write-Verbose "Today is the first Saturday: $($firstSaturday.ToString('dd/MM/yyyy'))"

  $snif = $env:COMPUTERNAME.Substring(8,3)
  
  $myHost = $env:COMPUTERNAME
  
  Write-Verbose "Hostname: $myHost"
  Write-Host "Hostname: $myHost"
  
  Write-Verbose "Computer substring: $snif"
  Write-Host "Computer substring: $snif"

  $plHost = "plpossrv$snif"
  $slHost = "slpossrv$snif"  

  Write-Verbose "Expected plpossrv hostname: $plHost"
  Write-Verbose "Expected slpossrv hostname: $slHost"

  Write-Host "Expected plpossrv hostname: $plHost"
  Write-Host "Expected slpossrv hostname: $slHost"

  if ($myHost -eq $plHost) {

    Write-Verbose "Hostname matches plpossrv, executing on slpossrv"
    Write-Host "Hostname is $plHost, executing on $slHost..."
    
    sqlcmd -E -Y 55 -S $slHost -Q "ALTER DATABASE GROCERY SET PARTNER FAILOVER"

  } elseif ($myHost -eq $slHost) {

    Write-Verbose "Hostname matches slpossrv, running locally" 
    Write-Host "Hostname is $slHost, running sqlcmd locally..."
    
    sqlcmd -E -Y 55 -S $env:COMPUTERNAME -Q "ALTER DATABASE GROCERY SET PARTNER FAILOVER"
  
  } else {
  
    Write-Verbose "Hostname does not match expected"
  
  }

} else {

  Write-Verbose "Today is not the first Saturday" 

}

Write-Host "Script complete!"
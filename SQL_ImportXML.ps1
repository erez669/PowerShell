# Check if running as admin, and re-launch if not
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
  $arguments = "& '" + $myinvocation.mycommand.definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  exit
}

$VerbosePreference = "Continue"

$source = "\\ivantiappsrv\IvantiShare\Packages\Servers_PL_SL\Server2019\FailOver"
$destination = "C:\install"

$filesToCopy = @("SQL_FailBack.ps1", "SQL_FailBack.xml")

foreach ($file in $filesToCopy) {

  Copy-Item -Path (Join-Path $source $file) -Destination $destination -Verbose

}

Write-Verbose "try to Import Schedule task SQL_FailBack to the task scheduler"

$taskName = "SQL_FailBack"

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
  Write-Host "Task $taskName is already exists" -ForegroundColor Yellow
}

else {
Invoke-Expression 'schtasks /create /xml "C:\install\SQL_FailBack.xml" /tn "SQL_FailBack" /ru "posprod\retalix_sqlinstall" /rp "Retalix123$"'
}
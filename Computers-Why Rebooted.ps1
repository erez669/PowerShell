# written by DHRUB BHARALI and modified by erez schwartz 3.3.23 (https://powershellguru.com/)
Clear-Host

Function Get-ComInfo {
param(
## Computers
$computers
)
 
"#"*160
"Server Reboot Report"
"Generated $(get-date)"
"Generated from $(gc env:computername)"
"#"*160
 
Get-WinEvent -ComputerName $computers -FilterHashtable @{logname='System'; id=1074}  |
ForEach-Object {
$rv = New-Object PSObject | Select-Object Date, User, Action, Process, Reason, ReasonCode, Comment
$rv.Date = $_.TimeCreated
$rv.User = $_.Properties[6].Value
$rv.Process = $_.Properties[0].Value
$rv.Action = $_.Properties[4].Value
$rv.Reason = $_.Properties[2].Value
$rv.ReasonCode = $_.Properties[3].Value
$rv.Comment = $_.Properties[5].Value
$rv
} | Select-Object Date, Action, Reason, User
}

############ Provide path in get content ##############
Get-Content "\\myserver\PowerShell\Computers.txt" | ForEach-Object {
    $computer = $_
    Get-ComInfo -computers $computer | ForEach-Object {
        $_ | Add-Member -MemberType NoteProperty -Name Computer -Value $computer -Force
        $_
    } | Tee-Object -FilePath "C:\Temp\ServerReboot_Report.txt" -Append
}

#Imports active directory module to only current session
Import-Module activedirectory

do {
cls
$User = Get-ADUser -Identity (Read-Host "Copy From Username")
$Domain = "shufersal.co.il"
$NewUser = Read-Host "New Username"
$userobj = Get-ADUser -LDAPFilter "(SAMAccountName=$NewUser)"
write-host "`n" # for creating space
if ($userobj -ne $null -or $NewUser -eq "quit") {Write-Warning "$NewUser is already existing, please try again" ;Start-Sleep -s 04; continue} else {"$NewUser is Available for use"}
write-host "`n" # for creating space
$FirstName = Read-Host "First Name (English)"
$LastName = Read-Host "Last Name (English)"
$attribute11 = Read-Host "First Name (Hebrew)"
$attribute12 = Read-Host "Last Name (Hebrew)"
$newID = Read-Host 'Enter New User ID Number'
$mobile = Read-Host 'Enter New User Mobile Number'
$SapNumber = Read-Host 'Enter EmployeeID (Sap Number 6 Digits)'
$attribute10 = Read-Host 'UserType (Shufersal\OutSource\Sapak) copy from brackets and click Enter'
$upn = $NewUser + "@$Domain"
$NewName = "$FirstName $LastName"
$Info = Get-ADUser -Identity $User -Properties Title,Department,extensionattribute13
$attribute13 = (Get-ADUser -Identity $User -Properties department).department

New-ADUser -SamAccountName $NewUser -Name $NewName -DisplayName $NewName -GivenName $firstname -Surname $lastname -UserPrincipalName $upn -MobilePhone $mobile -EmployeeID $SapNumber -Instance $Info -Path "OU=Users-Office365,DC=corp,DC=supersol,DC=co,DC=il" -AccountPassword (Read-Host "New Password" -AsSecureString) -ChangePasswordAtLogon 1 -Enabled $true
$Getusergroups = Get-ADUser -Identity $User -Properties memberof | Select-Object -ExpandProperty memberof
$Getusergroups | Add-ADGroupMember -Members $NewUser -verbose
write-host "`n" # for creating space
Set-ADUser -Identity $NewUser -add @{extensionAttribute9 = "$newID"}
$newValue = $newID -replace "^0"
Set-ADUser -identity $NewUser -replace @{extensionAttribute9=$newValue}
Set-ADUser -Identity $NewUser -add @{extensionAttribute10 = "$attribute10"}
Set-ADUser -Identity $NewUser -replace @{extensionAttribute11 = "$attribute11"}
Set-ADUser -Identity $NewUser -replace @{extensionAttribute12 = "$attribute12"}
Set-ADUser -Identity $NewUser -replace @{extensionAttribute13 = "$attribute13"}

# Create HomeDrive for the new account
$homeShare = "\\fileserv01\data\$NewUser"
$driveLetter = "V:"
New-Item $homeShare -Type Directory -Force

# assign HomeDrive permissions
$Acl = Get-Acl "$homeShare"
$Permissions = New-Object System.Security.AccessControl.FileSystemAccessRule("$NewUser", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$Acl.SetAccessRule($Permissions)
Set-Acl "$homeShare" $Acl
write-host "`n" # for creating space
write-host "Successfully added $NewUser full control permissions for HomeFolder"

Set-ADUser -Identity $NewUser -HomeDrive $driveLetter -HomeDirectory $homeShare
Set-ADUser -Identity $NewUser -ScriptPath "logonxp.bat"

write-host "`n" # for creating space
Write-Host "AD User $NewUser Creation Completed Successfully"

Start-Sleep -s 06 # delay command
} while ($NewUser -ne "quit")

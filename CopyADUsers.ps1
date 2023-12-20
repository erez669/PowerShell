#Imports active directory module to only current session
Import-Module activedirectory

do {
cls
$User = Get-ADUser -Identity (Read-Host "Copy From Username")
$Domain = "shufersal.co.il"
$NewUser = Read-Host "New Username (Logon Name)"
$userobj = Get-ADUser -LDAPFilter "(SAMAccountName=$NewUser)"
write-host "`n" # for creating space
if ($userobj -ne $null -or $NewUser -eq "quit") {Write-Warning "$NewUser is already exist, please try again" ;Start-Sleep -s 04; continue} else {"$NewUser is Available for use"}
write-host "`n" # for creating space
$FirstName = Read-Host "First Name (English)"
$LastName = Read-Host "Last Name (English)"
$attribute11 = Read-Host "First Name (Hebrew)"
$attribute12 = Read-Host "Last Name (Hebrew)"
$newID = Read-Host 'Enter New User ID Number'
$jobtitle = Read-Host 'Enter Job Title'
$mobile = Read-Host 'Enter New User Mobile Number'
$SapNumber = Read-Host 'Enter EmployeeID (Sap Number 6 Digits)'
$companyname = Read-Host 'Enter new user ComputerName\IP Address'
$attribute10 = Read-Host 'UserType (just copy & paste) --> Shufersal\OutSource\Sapak\Generic User\Mailbox User\Service User'
$upn = $NewUser + "@$Domain"
$NewName = "$FirstName $LastName"
$Info = Get-ADUser -Identity $User -Properties Title,Department,extensionattribute13
$attribute13 = (Get-ADUser -Identity $User -Properties department).department
$desc = (Get-ADUser -Identity $User -Properties description).description
$365 = Read-Host 'do you want to add office 365 license to the new account? (y/n)'

if ($365 -eq 'y') 
{
New-ADUser -SamAccountName $NewUser -Company $companyname -Name $NewName -Description $desc -DisplayName $NewName -Title $jobtitle -GivenName $firstname -Surname $lastname -UserPrincipalName $upn -MobilePhone $mobile -EmployeeID $SapNumber -Instance $Info -Path "OU=Users-Office365,DC=corp,DC=supersol,DC=co,DC=il" -AccountPassword (Read-Host "New Password" -AsSecureString) -ChangePasswordAtLogon 1 -Enabled $true

$Getusergroups = Get-ADUser -Identity $User -Properties memberof | Select-Object -ExpandProperty memberof
$Getusergroups | Add-ADGroupMember -Members $NewUser -verbose
Set-ADUser -Identity $NewUser -Replace @{userPrincipalName="$NewUser@shufersal.co.il"} # change upn suffix
$Groups = @("Office365_Lic_Default","Office365_Lic_Teams_Online","Office365 Required MFA","Office365_Lic_Office365_Apps")
ForEach ($Group in $Groups) {Add-ADPrincipalGroupMembership $NewUser -MemberOf $Group}
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
$detect = "supersol"
New-Item $homeShare -Type Directory -Force

Set-ADUser -Identity $NewUser -HomeDrive $driveLetter -HomeDirectory $homeShare
Set-ADUser -Identity $NewUser -ScriptPath "logonxp.bat"

Start-Sleep -s 07 # delay command

# assign HomeDrive permissions

$FolderLocation = "$homeShare"
$NewObject = "$detect\$NewUser"
$acl = Get-Acl -Path $FolderLocation
$giving = [System.Security.Principal.NTAccount]$NewObject
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($giving, "FullControl","ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($AccessRule)
set-acl -Path $FolderLocation -AclObject $acl

write-host "`n" # for creating space
write-host "Successfully added $NewUser full control permissions for HomeFolder"

write-host "`n" # for creating space
Write-Host "AD User $NewUser Creation Completed Successfully"

write-host "`n" # for creating space
write-host -nonewline "do you want to exit the script? (Y/N) "
$response = read-host
if ( $response -eq "Y" ) { break }
}

else

{

New-ADUser -SamAccountName $NewUser -Company $companyname -Name $NewName -Description $desc -DisplayName $NewName -Title $jobtitle -GivenName $firstname -Surname $lastname -UserPrincipalName $upn -MobilePhone $mobile -EmployeeID $SapNumber -Instance $Info -Path "OU=Users-Marlog,DC=corp,DC=supersol,DC=co,DC=il" -AccountPassword (Read-Host "New Password" -AsSecureString) -ChangePasswordAtLogon 1 -Enabled $true

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
$detect = "supersol"
New-Item $homeShare -Type Directory -Force

Set-ADUser -Identity $NewUser -HomeDrive $driveLetter -HomeDirectory $homeShare
Set-ADUser -Identity $NewUser -ScriptPath "logonxp.bat"

Start-Sleep -s 07 # delay command

# assign HomeDrive permissions

$FolderLocation = "$homeShare"
$NewObject = "$detect\$NewUser"
$acl = Get-Acl -Path $FolderLocation
$giving = [System.Security.Principal.NTAccount]$NewObject
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($giving, "FullControl","ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($AccessRule)
set-acl -Path $FolderLocation -AclObject $acl

write-host "`n" # for creating space
write-host "Successfully added $NewUser full control permissions for HomeFolder"

write-host "`n" # for creating space
Write-Host "AD User $NewUser Creation Completed Successfully"

write-host "`n" # for creating space
write-host -nonewline "do you want to exit the script? (Y/N) "
$response = read-host
if ( $response -eq "Y" ) { break }
}

} while ($NewUser -ne "quit")

Import-Module ActiveDirectory
Clear-Host
Write-Host "`n"
Write-Host "Active Directory Module was Loaded."
Write-Host "`n"

# Prompt for AD Account Name
$accountName = Read-Host "Enter AD Account name"
Write-Host "`n"
Write-Host "You entered the account name: $accountName"

# Search for Users
Write-Host "Searching for users..."
$users = Get-ADUser -Filter "SamAccountName -like '$accountName*'" -Properties UserPrincipalName -Verbose
Write-Host "Found $($users.Count) user(s) with name like $accountName."

# Change UPN Suffix
foreach ($user in $users) {
    $oldUPN = $user.UserPrincipalName
    $newUPN = $oldUPN -replace '@shufersal.co.il$', '@bestore.co.il'
    Write-Host "Changing UPN for $($user.SamAccountName) from $oldUPN to $newUPN..."
    Set-ADUser $user -UserPrincipalName $newUPN -Verbose
    Write-Host "Successfully changed UPN for $($user.SamAccountName) to $newUPN."
}

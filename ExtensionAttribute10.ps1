# Import the Active Directory module
Import-Module ActiveDirectory

Clear-Host

do {
    $username = Read-Host "Please enter AD user to update Attribute10 (or type 'exit' to quit)"
    
    if ($username -eq "exit") {
        break
    }

    try {
        $user = Get-ADUser -Identity $username -Properties extensionAttribute10, DistinguishedName

        # Extract OU from DistinguishedName
        $ou = ($user.DistinguishedName -split ',', 2)[1]
        
        # Display user information
        Write-Host "`nUser found:" -ForegroundColor Cyan
        Write-Host "Name: $($user.Name)" -ForegroundColor Cyan
        Write-Host "Username: $($user.SamAccountName)" -ForegroundColor Cyan
        Write-Host "Published At: $ou" -ForegroundColor Cyan
        
        if ([string]::IsNullOrEmpty($user.extensionAttribute10)) {
            do {
                Write-Host "`nCurrent extensionAttribute10 is empty. Please choose a value:"
                Write-Host "1. Shufersal"
                Write-Host "2. Outsource"
                Write-Host "3. Sapak"
                Write-Host "4. Generic User"
                Write-Host "5. Mailbox User"
                Write-Host "6. Service User"

                $choice = Read-Host "Enter the number of your choice"

                $newValue = switch ($choice) {
                    "1" { "Shufersal" }
                    "2" { "Outsource" }
                    "3" { "Sapak" }
                    "4" { "Generic User" }
                    "5" { "Mailbox User" }
                    "6" { "Service User" }
                    default { 
                        Write-Host "Invalid choice. Please enter a number between 1 and 7." -ForegroundColor Red
                        continue
                    }
                }

                if ($null -eq $newValue -and $choice -eq "7") {
                    Write-Host "Skipping this user." -ForegroundColor Yellow
                    break
                }
                elseif ($null -ne $newValue) {
                    Set-ADUser -Identity $username -Replace @{extensionAttribute10=$newValue}
                    Write-Host "User Attribute Successfully updated" -ForegroundColor Green
                    break
                }
            } while ($true)
        }
        else {
            Write-Host "`nextensionAttribute10 is not empty. Current value: $($user.extensionAttribute10)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Failed to update: $_" -ForegroundColor Red
    }

    Write-Host "`n" # Add a blank line for readability

} while ($true)

Write-Host "Script execution completed."

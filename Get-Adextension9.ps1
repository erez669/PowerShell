# ---------------------------------------------------------------------------
#                   This script was written by erez schwartz
# ---------------------------------------------------------------------------

Import-Module ActiveDirectory

$ErrorActionPreference = 'SilentlyContinue'

while ($true) {
    Clear-Host
    Write-Host "`n"
    Write-Host "Edit AD extensionAttribute9 IDnumber for Synerion`n"
    $Username = Read-Host 'Enter AD UserName'
    Write-Host "`n"
    $IDnumber = (Get-ADUser $Username -Properties extensionAttribute9).extensionAttribute9
    $currentID = Read-Host "Current IDnumber is $IDnumber. Do you want to edit? (y/n/r/c) r = remove first 0 / c = Change Existing"

    switch ($currentID) {
        'c' {
            Write-Host "`n"
            $newID = Read-Host 'Enter new ID Number'
            Set-ADUser -Identity $Username -replace @{extensionAttribute9 = $newID}
            $newValue = $newID -replace "^0"
            Set-ADUser -identity $Username -replace @{extensionAttribute9 = $newValue}
            Write-Host "`nValue Changed Successfully`n"
        }
        'y' {
            Write-Host "`n"
            $newID = Read-Host 'Enter ID Number'
            Set-ADUser -Identity $Username -add @{extensionAttribute9 = $newID}
            $newValue = $newID -replace "^0"
            Set-ADUser -identity $Username -replace @{extensionAttribute9 = $newValue}
            Write-Host "`nValue added to extensionAttribute9`n"
        }
        'r' {
            $newValue = $IDnumber -replace "^0"
            Set-ADUser -identity $Username -replace @{extensionAttribute9 = $newValue}
            Write-Host "`nThe first 0 digit was removed Successfully`n"
        }
        'n' {
            Write-Host "`nValue not changed`n"
        }
    }
    Start-Sleep -Seconds 5
}

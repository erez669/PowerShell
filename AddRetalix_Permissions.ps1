function Test-AdminRights {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Clear-Host

function Test-ExistingPermissions {
    param (
        [string]$FolderPath
    )
    
    if (-not (Test-Path $FolderPath)) {
        return $false
    }

    try {
        $acl = Get-Acl $FolderPath
        $everyoneSet = $false
        $kupaSet = $false

        foreach ($access in $acl.Access) {
            if ($access.IdentityReference.Value -eq "Everyone" -and 
                $access.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadAndExecute)) {
                $everyoneSet = $true
            }
            if ($access.IdentityReference.Value -eq "posprod\kupa" -and 
                $access.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::Modify)) {
                $kupaSet = $true
            }
        }

        return $everyoneSet -and $kupaSet
    }
    catch {
        return $false
    }
}

function Set-FolderPermission {
    param (
        [string]$FolderPath = $(throw "FolderPath is required")
    )
    
    Write-Host "Checking permissions for: $FolderPath"
    
    if (Test-ExistingPermissions -FolderPath $FolderPath) {
        Write-Host "Permissions already set correctly for $FolderPath" -ForegroundColor Green
        return $true
    }
    
    if (Test-Path $FolderPath) {
        try {
            $acl = Get-Acl $FolderPath
            
            # Set Read & Execute for Everyone
            $everyoneAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule( `
                "Everyone", `
                "ReadAndExecute", `
                "ContainerInherit,ObjectInherit", `
                "None", `
                "Allow")
            $acl.SetAccessRule($everyoneAccessRule)
            
            # Set Modify for posprod\kupa
            $kupaAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule( `
                "posprod\kupa", `
                "Modify", `
                "ContainerInherit,ObjectInherit", `
                "None", `
                "Allow")
            $acl.SetAccessRule($kupaAccessRule)
            
            Set-Acl $FolderPath $acl
            Write-Host "Successfully set new permissions for $FolderPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Error setting permissions: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
        return $true
    } else {
        Write-Host "Folder not found: $FolderPath" -ForegroundColor Red
        return $false
    }
}

# Check if running as admin
if (-not (Test-AdminRights)) {
    Write-Host "This script requires administrative privileges. Please run as administrator." -ForegroundColor Red
    exit
}

# Define paths
$paths = @(
    "C:\Program Files (x86)\Retalix",
    "C:\Program Files\Retalix",
    "C:\Retalix"
)

# Check if all existing paths already have correct permissions
$allPathsCorrect = $true
$existingPaths = $paths | Where-Object { Test-Path $_ }

if ($existingPaths.Count -eq 0) {
    Write-Host "No Retalix paths found! Please check if the software is installed." -ForegroundColor Red
    exit 1
}

foreach ($path in $existingPaths) {
    if (-not (Test-ExistingPermissions -FolderPath $path)) {
        $allPathsCorrect = $false
        break
    }
}

if ($allPathsCorrect) {
    Write-Host "All permissions are already set correctly!" -ForegroundColor Green
    exit 0
}

# If we get here, at least one path needs updating
foreach ($path in $paths) {
    if (Test-Path $path) {
        Write-Host "Processing path: $path" -ForegroundColor Cyan
        if (Set-FolderPermission -FolderPath $path) {
            Write-Host "Successfully processed $path" -ForegroundColor Green
        } else {
            Write-Host "Failed to process $path" -ForegroundColor Red
        }
    } else {
        Write-Host "Path not found: $path" -ForegroundColor Yellow
    }
}

Write-Host "Script completed!" -ForegroundColor Green
# SIG # Begin signature block
# MIIFqgYJKoZIhvcNAQcCoIIFmzCCBZcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDW+NryUC89L1os
# Jsxi6SWQDNQHqmr1NXCslXr8MSCcT6CCAxgwggMUMIIB/KADAgECAhAT6q3HWCF/
# k09myhWMiDXEMA0GCSqGSIb3DQEBCwUAMCIxIDAeBgNVBAMMF1Bvd2VyU2hlbGwg
# Q29kZSBTaWduaW5nMB4XDTI1MDIxNzA2NDUxMloXDTMwMDIxNzA2NTUxMlowIjEg
# MB4GA1UEAwwXUG93ZXJTaGVsbCBDb2RlIFNpZ25pbmcwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQDMDttwRVAad2fG6XeNGTpOky/wUoPUANExW7aHDlf8
# 7y4L/7xi8xavw5sLUqp9Q4gXGG9BnFNwREXBzfjEIWjE6WFH12YyFjGgB6e6iazZ
# tvymc2Zp8dYOUEIHvNdsS5HaZMw+uWMsJM2gHdk1JmRDd90c1HYN1DB2DuKYJ5fa
# v2qQMF4imRnAd2WQULEoVhnmJbKmgA2hf+9xFQB+aYpwJu4gJ1gpWirKJtG835Mm
# tU/NSoJW43sanhb/cKr1WuqAhIQi23A5iJKIW+q791x+jKyOYnXwp72uiVXGy1U+
# c2WoFzjQ04l8j3xanCOYgemaHE0Mpct0cJaeQThkHVGNAgMBAAGjRjBEMA4GA1Ud
# DwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUeS/d4WTS
# omaKU3Kcl0EsG6n00BowDQYJKoZIhvcNAQELBQADggEBAD7Sj/4lp/NUjxN9LLIV
# fvg5UCvBlGd5vh6chEkIGGMavpgEDOy0zzNxjm+b1eNYdk8YkRvpX1o1XvsNfPMq
# XQyp4CXOqe+uMKkUrTqdbApGxEY9gXmEffVynB3YjcY6uRXgTBoyovoMmOk+6K2x
# hUqniWFAtjKlfjRRqmaxUYiSD8e5qrFTTcDQ3XwTZD7woe+kYP83B//aEH48cHRl
# gIwnX72NZWxmRfCtQ12pW+GD12ynJHKOAhnDe0ECKhngqmKx4ZfkmNMfntQ9QMgq
# a2e3Hpgz9yW+qtw2pzs2Kze99aAMkcE79yh9eBx6jfH4SstceNDtxaELh2AsX/Ay
# CkMxggHoMIIB5AIBATA2MCIxIDAeBgNVBAMMF1Bvd2VyU2hlbGwgQ29kZSBTaWdu
# aW5nAhAT6q3HWCF/k09myhWMiDXEMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQB
# gjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAYZO97Y
# g6yA/DILYq5RVakGT7K8uSBbXvYHaSZ20/ngMA0GCSqGSIb3DQEBAQUABIIBAGK5
# STjYPxDocDPdK08VjadSRdBEffUvtGVjALZNghUEMcv54NjyT0u0w81p8meAfRdF
# aoBokvUVHEwxScpO8rWb0SZjH8LIWkkm0JD5mJtG8Tx/FwRV4GFwh8rV85AN9TCT
# C0fVIc8+1RVgXX/VKmuEiL473GYZ5FTQJRpIbhgVv84FzH0YRsUyz8uDAKtOt+qZ
# R5uEwOdjvtnBumHQui+PGVdfrekJ1H67Ztv5oy/GuNm5ir7GHqwmzhBo1xXebZWB
# 8tVzQkLtXdKMl66KufexaGdOjDrBMwI+jsieekYYyBFxBv0LXAg+D+GDgZLgi8av
# vv1Oc53169BOHZgSaPQ=
# SIG # End signature block

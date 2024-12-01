# Clear the console for better visibility
Clear-Host

# Function to get all available drives
function Get-SystemDrives {
    Get-WmiObject Win32_LogicalDisk | 
    Where-Object { $_.DriveType -eq 3 } | # Filter for local drives only
    Select-Object -ExpandProperty DeviceID
}

# Function to handle folder operations
function Remove-MfeDeepRemFolder {
    param (
        [string]$folderPath
    )
    
    try {
        Write-Host "Processing folder: $folderPath" -ForegroundColor Cyan
        
        # Step 1: Take ownership using elevated privileges
        Write-Host "Taking ownership of the folder..." -ForegroundColor Cyan
        $takeownResult = takeown.exe /F "$folderPath" /R /D Y 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Warning during takeown operation: $takeownResult" -ForegroundColor Yellow
        }
        
        # Step 2: Grant System full control first
        Write-Host "Granting SYSTEM full control..." -ForegroundColor Cyan
        $systemAclResult = icacls.exe "$folderPath" /grant "SYSTEM:(OI)(CI)F" /T /C 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Warning during SYSTEM permissions: $systemAclResult" -ForegroundColor Yellow
        }
        
        # Step 3: Grant Administrators full control
        Write-Host "Granting Administrators full control..." -ForegroundColor Cyan
        $adminAclResult = icacls.exe "$folderPath" /grant "Administrators:(OI)(CI)F" /T /C 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Warning during Administrators permissions: $adminAclResult" -ForegroundColor Yellow
        }
        
        # Step 4: Set owner to Everyone
        Write-Host "Setting 'Everyone' as the owner..." -ForegroundColor Cyan
        $setownerResult = icacls.exe "$folderPath" /setowner "Everyone" /T /C 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Warning during setowner operation: $setownerResult" -ForegroundColor Yellow
        }
        
        # Step 5: Grant Everyone full control
        Write-Host "Granting 'Everyone' full control permissions..." -ForegroundColor Cyan
        $everyoneAclResult = icacls.exe "$folderPath" /grant "Everyone:(OI)(CI)F" /T /C 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Warning during Everyone permissions: $everyoneAclResult" -ForegroundColor Yellow
        }
        
        # Step 6: Reset ACLs to remove any deny entries
        Write-Host "Resetting ACLs..." -ForegroundColor Cyan
        $resetAclResult = icacls.exe "$folderPath" /reset /T /C 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Warning during ACL reset: $resetAclResult" -ForegroundColor Yellow
        }
        
        # Final Step: Delete the folder
        Write-Host "Attempting to delete the folder..." -ForegroundColor Cyan
        Remove-Item -Path $folderPath -Recurse -Force -ErrorAction Stop
        Write-Host "Successfully deleted folder: $folderPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error processing $folderPath : $_" -ForegroundColor Red
        return $false
    }
}

# Main script execution
try {
    $folderName = "`$MfeDeepRem"
    $foldersFound = $false
    $successCount = 0
    $failureCount = 0
    
    Write-Host "Searching for $folderName across all drives..." -ForegroundColor Cyan
    
    # Get all system drives and search for the folder
    foreach ($drive in Get-SystemDrives) {
        $currentPath = Join-Path $drive $folderName
        
        if (Test-Path $currentPath) {
            $foldersFound = $true
            Write-Host "`nFound folder at: $currentPath" -ForegroundColor Yellow
            
            # Attempt to remove the folder
            if (Remove-MfeDeepRemFolder -folderPath $currentPath) {
                $successCount++
            } else {
                $failureCount++
            }
        }
    }
    
    # Final status report
    Write-Host "`nOperation Complete!" -ForegroundColor Cyan
    if (-not $foldersFound) {
        Write-Host "No $folderName folders were found on any drive." -ForegroundColor Yellow
    } else {
        Write-Host "Successfully processed: $successCount folder(s)" -ForegroundColor Green
        if ($failureCount -gt 0) {
            Write-Host "Failed to process: $failureCount folder(s)" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "`nCritical error occurred: $_" -ForegroundColor Red
}
finally {
    Write-Host "`nScript execution completed." -ForegroundColor Cyan
}
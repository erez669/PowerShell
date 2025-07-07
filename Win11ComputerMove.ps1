# Windows 11 Computer Detection and Move - Using Pure LDAP/ADSI
# No RSAT or additional tools required - uses built-in .NET libraries

[CmdletBinding()]
param(
    [switch]$WhatIf
)

Clear-Host

# Add required assemblies
Add-Type -AssemblyName System.DirectoryServices

# Define variables
$domainDN = "DC=corp,DC=supersol,DC=co,DC=il"
$targetOU = "OU=Win11,OU=MarlogRishon,OU=Workstations,DC=corp,DC=supersol,DC=co,DC=il"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $scriptPath "Win11ComputerMove.log"

# Function to write to log
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}

# Create log directory if it doesn't exist and recreate log file
$logDir = Split-Path $logFile -Parent
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force
}

# Always recreate log file (overwrite existing) to prevent huge files
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}
New-Item -ItemType File -Path $logFile -Force | Out-Null

if ($WhatIf) {
    Write-Log "Starting Windows 11 computer detection and move process (PREVIEW MODE)"
} else {
    Write-Log "Starting Windows 11 computer detection and move process"
}

try {
    # Connect to Active Directory using LDAP
    Write-Log "Connecting to Active Directory using LDAP..."
    
    $directoryEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$domainDN")
    $searcher = New-Object System.DirectoryServices.DirectorySearcher($directoryEntry)
    
    # Search for Windows 11 computers
    $searcher.Filter = "(&(objectClass=computer)(operatingSystem=Windows 11*))"
    $searcher.PropertiesToLoad.Add("name") | Out-Null
    $searcher.PropertiesToLoad.Add("operatingSystem") | Out-Null
    $searcher.PropertiesToLoad.Add("operatingSystemVersion") | Out-Null
    $searcher.PropertiesToLoad.Add("distinguishedName") | Out-Null
    $searcher.PropertiesToLoad.Add("description") | Out-Null
    
    Write-Log "Searching for Windows 11 computers..."
    $searchResults = $searcher.FindAll()
    
    Write-Log "Found $($searchResults.Count) Windows 11 computers"
    
    # Check if target OU exists
    try {
        $targetOUEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$targetOU")
        $targetOUName = $targetOUEntry.Name
        Write-Log "Target OU verified: $targetOU"
        $targetOUEntry.Close()
    }
    catch {
        Write-Log "ERROR: Target OU does not exist or cannot be accessed: $targetOU"
        Write-Log "Please create the OU first or verify the path and permissions"
        exit 1
    }
    
    # Process each Windows 11 computer
    $movedCount = 0
    $skippedCount = 0
    $errorCount = 0
    
    # First, filter out computers already in target OU
    $computersToProcess = @()
    foreach ($result in $searchResults) {
        $computerDN = $result.Properties["distinguishedName"][0]
        if ($computerDN -notlike "*$targetOU*") {
            $computersToProcess += $result
        } else {
            $skippedCount++
        }
    }
    
    Write-Log "Computers already in target OU: $skippedCount"
    Write-Log "Computers that need to be moved: $($computersToProcess.Count)"
    Write-Log ""
    
    if ($WhatIf) {
        # In WhatIf mode, show summary and ask for confirmation
        Write-Log "PREVIEW MODE - Computers that would be moved:"
        Write-Log "="*60
        
        foreach ($result in $computersToProcess) {
            $computerName = $result.Properties["name"][0]
            $operatingSystem = $result.Properties["operatingSystem"][0]
            $computerDN = $result.Properties["distinguishedName"][0]
            $currentOU = $computerDN -replace '^CN=[^,]+,',''
            Write-Log "  - $computerName ($operatingSystem)"
            Write-Log "    FROM: $currentOU"
        }
        
        Write-Log "="*60
        Write-Log "SUMMARY:"
        Write-Log "Total Windows 11 computers found: $($searchResults.Count)"
        Write-Log "Already in correct OU: $skippedCount"
        Write-Log "Need to be moved: $($computersToProcess.Count)"
        Write-Log ""
        
        # Ask for confirmation in WhatIf mode
        if ($computersToProcess.Count -gt 0) {
            Write-Host ""
            Write-Host "PREVIEW COMPLETE" -ForegroundColor Yellow
            Write-Host "Found $($computersToProcess.Count) Windows 11 computers that need to be moved to the target OU." -ForegroundColor White
            Write-Host ""
            $response = Read-Host "Do you want to proceed with moving these computers? (y/n)"
            
            if ($response -eq 'y' -or $response -eq 'Y') {
                Write-Log "User confirmed to proceed with the move operation"
                Write-Log ""
                Write-Log "EXECUTING MOVE OPERATIONS:"
                Write-Log "="*60
                
                # Execute the moves immediately
                $movedCount = 0
                $errorCount = 0
                
                foreach ($result in $computersToProcess) {
                    $computerName = $result.Properties["name"][0]
                    $operatingSystem = $result.Properties["operatingSystem"][0]
                    $osVersion = if ($result.Properties["operatingSystemVersion"].Count -gt 0) { $result.Properties["operatingSystemVersion"][0] } else { "Unknown" }
                    $computerDN = $result.Properties["distinguishedName"][0]
                    
                    Write-Log "Processing: $computerName"
                    Write-Log "  OS: $operatingSystem"
                    Write-Log "  Version: $osVersion"
                    Write-Log "  Current OU: $($computerDN -replace '^CN=[^,]+,','')"
                    
                    # Move computer to target OU
                    try {
                        Write-Log "  Attempting to move $computerName..."
                        
                        # Get the computer object
                        $computerEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$computerDN")
                        
                        # Get the target OU object
                        $targetEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$targetOU")
                        
                        # Move the computer
                        $computerEntry.MoveTo($targetEntry)
                        $computerEntry.CommitChanges()
                        
                        Write-Log "  SUCCESS: Moved $computerName to $targetOU"
                        $movedCount++
                        
                        # Clean up
                        $computerEntry.Close()
                        $targetEntry.Close()
                        
                    }
                    catch {
                        Write-Log "  ERROR: Failed to move $computerName - $($_.Exception.Message)"
                        $errorCount++
                    }
                }
                
                # Final summary for WhatIf with execution
                Write-Log "="*60
                Write-Log "EXECUTION SUMMARY:"
                Write-Log "Total Windows 11 computers found: $($searchResults.Count)"
                Write-Log "Computers already in correct OU: $skippedCount"
                Write-Log "Successfully moved: $movedCount"
                Write-Log "Errors: $errorCount"
                Write-Log "="*60
                
                if ($movedCount -gt 0) {
                    Write-Host ""
                    Write-Host "SUCCESS: Moved $movedCount computers to the target OU" -ForegroundColor Green
                    if ($errorCount -gt 0) {
                        Write-Host "WARNING: $errorCount computers failed to move - check log for details" -ForegroundColor Yellow
                    }
                } elseif ($errorCount -gt 0) {
                    Write-Host "ERROR: All move operations failed - check log for details" -ForegroundColor Red
                }
                
            } else {
                Write-Log "User chose not to proceed with the move operation"
            }
        } else {
            Write-Log "No computers need to be moved - all Windows 11 computers are already in the correct OU"
        }
        
        Write-Log "Script completed successfully"
        
        # Clean up and exit
        $searcher.Dispose()
        $directoryEntry.Close()
        return
    }
    
    # If not WhatIf mode, process each computer automatically
    Write-Log "EXECUTING MOVE OPERATIONS (no prompts):"
    Write-Log "="*60
    
    foreach ($result in $computersToProcess) {
        $computerName = $result.Properties["name"][0]
        $operatingSystem = $result.Properties["operatingSystem"][0]
        $osVersion = if ($result.Properties["operatingSystemVersion"].Count -gt 0) { $result.Properties["operatingSystemVersion"][0] } else { "Unknown" }
        $computerDN = $result.Properties["distinguishedName"][0]
        $description = if ($result.Properties["description"].Count -gt 0) { $result.Properties["description"][0] } else { "No description" }
        
        Write-Log "Processing: $computerName"
        Write-Log "  OS: $operatingSystem"
        Write-Log "  Version: $osVersion"
        Write-Log "  Current OU: $($computerDN -replace '^CN=[^,]+,','')"
        
        # Move computer to target OU (no prompts in normal mode)
        try {
            # Perform the move using LDAP
            Write-Log "  Attempting to move $computerName..."
            
            # Get the computer object
            $computerEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$computerDN")
            
            # Get the target OU object
            $targetEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$targetOU")
            
            # Move the computer
            $computerEntry.MoveTo($targetEntry)
            $computerEntry.CommitChanges()
            
            Write-Log "  SUCCESS: Moved $computerName to $targetOU"
            $movedCount++
            
            # Clean up
            $computerEntry.Close()
            $targetEntry.Close()
            
        }
        catch {
            Write-Log "  ERROR: Failed to move $computerName - $($_.Exception.Message)"
            $errorCount++
        }
    }
    
    # Summary (only for non-WhatIf mode)
    Write-Log "="*60
    Write-Log "EXECUTION SUMMARY:"
    Write-Log "Total Windows 11 computers found: $($searchResults.Count)"
    Write-Log "Computers already in correct OU: $skippedCount"
    Write-Log "Successfully moved: $movedCount"
    Write-Log "Errors: $errorCount"
    Write-Log "="*60
    
    if ($movedCount -gt 0) {
        Write-Host ""
        Write-Host "SUCCESS: Moved $movedCount computers to the target OU" -ForegroundColor Green
        if ($errorCount -gt 0) {
            Write-Host "WARNING: $errorCount computers failed to move - check log for details" -ForegroundColor Yellow
        }
    } elseif ($errorCount -gt 0) {
        Write-Host "ERROR: All move operations failed - check log for details" -ForegroundColor Red
    } else {
        Write-Host "INFO: No computers needed to be moved" -ForegroundColor Blue
    }
    
    # Clean up
    $searcher.Dispose()
    $directoryEntry.Close()
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)"
    Write-Log "Stack trace: $($_.Exception.StackTrace)"
    exit 1
}

Write-Log "Script completed successfully"

<#
USAGE EXAMPLES:

1. Preview mode with confirmation prompt:
   .\Win11ComputerMove.ps1 -WhatIf
   (Shows what would be moved and asks if you want to proceed)

2. Execute moves automatically (no prompts):
   .\Win11ComputerMove.ps1
   (Automatically moves all Windows 11 computers to target OU)

REQUIREMENTS:
- Domain-joined computer
- User account with permissions to query and move AD computer objects
- No additional software or modules required (uses built-in .NET libraries)

PERMISSIONS NEEDED:
- Read permissions on the domain/OUs to search for computers
- Write permissions to move computer objects
- Read/Write permissions on the target OU

LOG FILE BEHAVIOR:
- Log file is recreated (overwritten) every time the script runs
- Prevents log file from growing huge over time
- Log file location: Same directory as the script (Win11ComputerMove.log)

NOTES:
- This script uses pure LDAP/ADSI - no RSAT required
- All Windows installations have System.DirectoryServices available
- WhatIf mode shows preview and asks for confirmation
- Normal mode executes moves automatically without prompts
- The script creates detailed logs for auditing purposes
#>
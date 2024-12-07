# Enhanced Printer Migration Script
# This script migrates printers from old print servers (PRTSRVR and PRTSRVM) to a new server
# Compatible with Windows 10 and above only

#Requires -Version 3.0

param(
    [Parameter(Mandatory=$false)]
    [string]$NewPrintServer,
    
    [Parameter(Mandatory=$false)]
    [string[]]$OldPrintServers,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath
)

# Then set default values
if (-not $NewPrintServer) {
    $NewPrintServer = "PRTSRV"
}

if (-not $OldPrintServers) {
    $OldPrintServers = @("PRTSRVR", "PRTSRVM")
}

if (-not $LogPath) {
    $LogPath = "C:\Temp\PrinterMigration.txt"
}

Clear-Host

# Function to write colored output with logging
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Section')]
        [string]$Type = 'Info',
        [switch]$Console
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = switch ($Type) {
        'Section'  { "`n$timestamp - ==================== $Message ====================" }
        'Success'  { "$timestamp - [SUCCESS] $Message" }
        'Warning'  { "$timestamp - [WARNING] $Message" }
        'Error'    { "$timestamp - [ERROR] $Message" }
        default    { "$timestamp - $Message" }
    }
    
    # Write to log file
    try {
        $logMessage | Out-File -FilePath $script:logFile -Append -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to write to log file: $_ `nLog message: $logMessage" -ForegroundColor Red
    }

    # Write to console if requested
    if ($Console) {
        $color = switch ($Type) {
            'Section'  { 'Cyan' }
            'Success'  { 'Green' }
            'Warning'  { 'Yellow' }
            'Error'    { 'Red' }
            default    { 'White' }
        }
        Write-Host $Message -ForegroundColor $color
    }
}

# Function to check system requirements
function Test-SystemRequirements {
    Write-Log "Checking system requirements..." -Type Section -Console
    
    try {
        # Check OS version
        $osInfo = Get-WmiObject Win32_OperatingSystem
        $osVersion = [System.Version]($osInfo.Version)
        $isWindows10OrHigher = $osVersion -ge [System.Version]"10.0"
        
        if (-not $isWindows10OrHigher) {
            Write-Log "This script requires Windows 10 or higher. Current version: $($osInfo.Caption)" -Type Error -Console
            return $false
        }
        Write-Log "OS Version check passed: $($osInfo.Caption)" -Type Success -Console

        # Check if running on WKS/POS/ONL machine
        if ($env:COMPUTERNAME -match '^(WKS|POS|ONL)[-_]?') {
            Write-Log "This script is not intended to run on WKS, POS, or ONL machines" -Type Error -Console
            return $false
        }
        Write-Log "Computer name check passed: $env:COMPUTERNAME" -Type Success -Console

        return $true
    }
    catch {
        Write-Log "Error checking system requirements: $_" -Type Error -Console
        return $false
    }
}

# Function to initialize logging
function Initialize-Logging {
    Write-Host "`nInitializing logging system..." -ForegroundColor Cyan
    
    try {
        $logDir = Split-Path -Parent $LogPath
        if (-not (Test-Path -Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null
            Write-Host "Created log directory: $logDir" -ForegroundColor Green
        }
        
        $script:logFile = $LogPath
        if (Test-Path $script:logFile) {
            # Archive old log file
            $archiveDir = Join-Path $logDir "Archives"
            if (-not (Test-Path $archiveDir)) {
                New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
            }
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            Move-Item -Path $script:logFile -Destination (Join-Path $archiveDir "PrinterMigration_$timestamp.txt") -Force
        }
        
        New-Item -ItemType File -Path $script:logFile -Force | Out-Null
        Write-Host "Log file initialized at: $script:logFile" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to initialize logging: $_" -ForegroundColor Red
        return $false
    }
}

# Function to get default printer from registry
function Get-DefaultPrinterFromRegistry {
    try {
        $registryPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows"
        $defaultPrinter = Get-ItemProperty -Path $registryPath -Name "Device" -ErrorAction Stop
        if ($defaultPrinter) {
            return ($defaultPrinter.Device -split ',')[0]
        }
    }
    catch {
        Write-Log "Error getting default printer from registry: $_" -Type Warning -Console
    }
    return $null
}

# Function to get network printers from old servers
function Get-OldServerPrinters {
    Write-Log "Detecting printers from old servers..." -Type Section -Console
    
    try {
        $networkPrinters = Get-WmiObject Win32_Printer | Where-Object { $_.Network -eq $true }
        $oldServerPrinters = @()
        
        foreach ($printer in $networkPrinters) {
            if ($printer.Name -match "\\\\([^\\]+)\\(.+)$") {
                $serverName = $matches[1].ToUpper()
                if ($OldPrintServers -contains $serverName) {
                    $oldServerPrinters += [PSCustomObject]@{
                        Name = $printer.Name
                        Server = $serverName
                        ShareName = $matches[2]
                        Default = $printer.Default
                    }
                    Write-Log "Found old server printer: $($printer.Name)$(if($printer.Default){' [Default]'})" -Type Info -Console
                }
            }
        }
        
        $count = $oldServerPrinters.Count
        if ($count -eq 0) {
            Write-Log "No printers found from old servers ($($OldPrintServers -join ', '))" -Type Warning -Console
        } else {
            Write-Log "Found $count printer(s) from old servers" -Type Success -Console
        }
        
        return $oldServerPrinters
    }
    catch {
        Write-Log "Error detecting printers: $_" -Type Error -Console
        return @()
    }
}

# Function to remove a printer
function Remove-UserPrinter {
    param([string]$PrinterPath)
    
    if ([string]::IsNullOrEmpty($PrinterPath)) {
        Write-Log "Invalid printer path provided" -Type Error -Console
        return $false
    }
    
    Write-Log "Removing printer: $PrinterPath" -Type Info -Console
    
    try {
        # Try PrintUI first
        $process = Start-Process rundll32 -ArgumentList "printui.dll,PrintUIEntry /dn /n`"$PrinterPath`" /q" -Wait -PassThru -WindowStyle Hidden
        Start-Sleep -Seconds 2
        
        # Fallback to net use only if needed
        $retryCount = 0
        while ((Get-WmiObject Win32_Printer | Where-Object { $_.Name -eq $PrinterPath }) -and $retryCount -lt 2) {
            $process = Start-Process cmd.exe -ArgumentList "/c net use `"$PrinterPath`" /delete /y" -Wait -PassThru -WindowStyle Hidden
            Start-Sleep -Seconds 1
            $retryCount++
        }
        
        $printerExists = Get-WmiObject Win32_Printer | Where-Object { $_.Name -eq $PrinterPath }
        if (-not $printerExists) {
            Write-Log "Successfully removed printer" -Type Success -Console
            return $true
        } else {
            Write-Log "Failed to remove printer" -Type Error -Console
            return $false
        }
    }
    catch {
        Write-Log "Error removing printer: $_" -Type Error -Console
        return $false
    }
}

# Function to add a printer
function Add-UserPrinter {
    param(
        [string]$PrinterPath,
        [bool]$SetDefault = $false    # We'll keep this parameter but won't use it
    )
    
    if ([string]::IsNullOrEmpty($PrinterPath)) {
        Write-Log "Invalid printer path provided" -Type Error -Console
        return $false
    }
    
    Write-Log "Adding printer: $PrinterPath" -Type Info -Console
    
    try {
        # Try PrintUI first
        $process = Start-Process rundll32 -ArgumentList "printui.dll,PrintUIEntry /in /n`"$PrinterPath`" /q" -Wait -PassThru -WindowStyle Hidden
        Start-Sleep -Seconds 3
        
        # Verify printer was added
        $printerAdded = Get-WmiObject Win32_Printer | Where-Object { $_.Name -eq $PrinterPath }
        
        if (-not $printerAdded) {
            # Fallback to WScript.Network
            Write-Log "PrintUI failed, trying WScript.Network..." -Type Warning -Console
            $network = New-Object -ComObject WScript.Network
            $network.AddWindowsPrinterConnection($PrinterPath)
            Start-Sleep -Seconds 2
            
            $printerAdded = Get-WmiObject Win32_Printer | Where-Object { $_.Name -eq $PrinterPath }
        }
        
        if ($printerAdded) {
            Write-Log "Successfully added printer" -Type Success -Console
            # Removed default printer setting from here as it will be handled separately
            return $true
        } else {
            Write-Log "Failed to add printer" -Type Error -Console
            return $false
        }
    }
    catch {
        Write-Log "Error adding printer: $_" -Type Error -Console
        return $false
    }
}

# Main script execution
try {
    Write-Host "`n=== Printer Migration Script ===" -ForegroundColor Cyan
    Write-Host "Target Server: $NewPrintServer" -ForegroundColor White
    Write-Host "Source Servers: $($OldPrintServers -join ', ')" -ForegroundColor White
    Write-Host "================================`n" -ForegroundColor Cyan
    
    # Initialize logging
    if (-not (Initialize-Logging)) {
        Write-Host "Critical Error: Failed to initialize logging. Exiting..." -ForegroundColor Red
        exit 1
    }
    
    # Check system requirements
    if (-not (Test-SystemRequirements)) {
        Write-Log "System requirements not met. Exiting..." -Type Error -Console
        exit 0
    }
    
    # Get printers from old servers
    $printersToMigrate = Get-OldServerPrinters
    if ($printersToMigrate.Count -eq 0) {
        Write-Log "No printers to migrate. Exiting..." -Type Warning -Console
        exit 0
    }
    
    # Migration process
    Write-Log "Starting migration process..." -Type Section -Console
    $successCount = 0
    $failedPrinters = @()

    $currentDefaultPrinter = Get-DefaultPrinterFromRegistry
    Write-Log "Current default printer from registry: $currentDefaultPrinter" -Type Info -Console
    
    foreach ($printer in $printersToMigrate) {
        Write-Log "Processing printer $($printer.Name)..." -Type Info -Console
        
        # Skip if printer is already on new server
        if ($printer.Server -eq $NewPrintServer) {
            Write-Log "Printer already on target server" -Type Success -Console
            $successCount++
            continue
        }
        
        $newPrinterPath = "\\$NewPrintServer\$($printer.ShareName)"
        Write-Log "Target path: $newPrinterPath" -Type Info -Console
        
        $migrationSuccess = $false
        if (Remove-UserPrinter -PrinterPath $printer.Name) {
            if (Add-UserPrinter -PrinterPath $newPrinterPath -SetDefault $printer.Default) {
                $successCount++
                $migrationSuccess = $true
            }
        }
        
        if (-not $migrationSuccess) {
            $failedPrinters += $printer.Name
            Write-Log "Attempting to restore original printer..." -Type Warning -Console
            Add-UserPrinter -PrinterPath $printer.Name -SetDefault $printer.Default
        }
    }
    
    # Display summary
    Write-Log "Migration Summary" -Type Section -Console

    if ($currentDefaultPrinter) {
    $oldServerPattern = $OldPrintServers -join '|'
    if ($currentDefaultPrinter -match "\\\\($oldServerPattern)\\(.+)$") {
        # The old default printer was from an old server, need to update the path
        $newDefaultPrinterPath = "\\$NewPrintServer\$($matches[2])"
        try {
            (New-Object -ComObject WScript.Network).SetDefaultPrinter($newDefaultPrinterPath)
            Write-Log "Restored default printer to: $newDefaultPrinterPath" -Type Success -Console
        }
        catch {
            Write-Log "Failed to restore default printer: $_" -Type Warning -Console
        }
    }
    else {
        # The default printer wasn't from an old server, restore it as is
        try {
            (New-Object -ComObject WScript.Network).SetDefaultPrinter($currentDefaultPrinter)
            Write-Log "Restored original default printer: $currentDefaultPrinter" -Type Success -Console
        }
        catch {
            Write-Log "Failed to restore original default printer: $_" -Type Warning -Console
        }
    }
}

    Write-Host "`nResults:" -ForegroundColor Cyan
    # Initialize counters once
    $totalProcessed = @($printersToMigrate).Count  # Force array counting
    $totalSuccess = if ($null -eq $successCount) { 0 } else { $successCount }
    $totalFailed = if ($null -eq $failedPrinters) { 0 } else { @($failedPrinters).Count }
    # Display results
    Write-Host "- Total Processed: $totalProcessed" -ForegroundColor White
    Write-Host "- Successfully Migrated: $totalSuccess" -ForegroundColor Green
    Write-Host "- Failed Migrations: $totalFailed" -ForegroundColor $(if($totalFailed -eq 0){'Green'}else{'Red'})
    # Add detailed summary to log file
    Write-Log "Migration Summary:" -Type Info
    Write-Log "- Total Processed: $totalProcessed" -Type Info
    Write-Log "- Successfully Migrated: $totalSuccess" -Type Info
    Write-Log "- Failed Migrations: $totalFailed" -Type Info
    # Display failed printers if any
    if ($failedPrinters.Count -gt 0) {
        Write-Host "`nFailed Printers:" -ForegroundColor Yellow
        foreach ($printer in $failedPrinters) {
            Write-Host "- $printer" -ForegroundColor Red
            Write-Log "Failed to migrate: $printer" -Type Error
        }
    }
    # Separator for better visibility (top)
    Write-Host "`n================================" -ForegroundColor Cyan
    # Display current network printers
    Write-Log "Current Network Printers:" -Type Section -Console
    Get-WmiObject Win32_Printer | Where-Object { $_.Network -eq $true } | ForEach-Object {
        $printerInfo = "- $($_.Name)$(if($_.Default){' [Default]'})"
        Write-Host $printerInfo -ForegroundColor White
        Write-Log $printerInfo
    }
    # Separator for better visibility (bottom)
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "`nMigration completed. Log file: $script:logFile" -ForegroundColor Green
    exit 0
}
catch {
    Write-Log "Critical error occurred: $_" -Type Error -Console
    Write-Log $_.ScriptStackTrace -Type Error
    exit 1
}
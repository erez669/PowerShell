<#
.SYNOPSIS
    Toshiba POS BIOS Configuration Deployment Script
.DESCRIPTION
    Detects Toshiba POS model (E85/E86/E70), copies BIOS tools, and applies configuration.
    Fully compatible with PowerShell v2.0 and NT AUTHORITY\SYSTEM.
.NOTES
    Version: 2.3 - Production Ready
    - Combined: Claude's robust error handling + Gemini's Add-Content optimization
    - Fixed: FileStream handle errors via process isolation
    - Enhanced: Comprehensive validation and logging
    - Author: Erez Schwartz
#>

# --- Variables ---
$SourcePathE85 = "\\myserver\myshare\Packages\POS\BiosUpdate\Toshiba_E85_BiosTool"
$SourcePathE86 = "\\myserver\myshare\Packages\POS\BiosUpdate\Toshiba_E86_BiosTool"
$SourcePathE70 = "\\myserver\myshare\Packages\POS\BiosUpdate\Toshiba_E70_BiosTool"
$DestinationRoot = "D:\"
$SupportedModels = @("4900E85", "4900785", "4900786", "4900E86", "4852E70", "4852570")

# --- Logging Function (Optimized) ---
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    
    # Always write to console for Ivanti visibility
    Write-Output $logMessage
    
    # Write to log file if available
    if ($script:LogFile) {
        $logDir = Split-Path $script:LogFile -Parent
        if (Test-Path $logDir) {
            try {
                # Add-Content is more efficient for appending in PS v2.0
                Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
            } catch {
                # Silently fail log writes to avoid breaking deployment
            }
        }
    }
}

Write-Output "=========================================="
Write-Output "BIOS Configuration Deployment Started"
Write-Output "=========================================="

# --- 1. Identify System (v2.0 Compatible) ---
try {
    $ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop
    $ComputerModel = $ComputerSystem.Model.Trim()
    Write-Output "Detected Model: $ComputerModel"
} catch {
    Write-Output "ERROR: Failed to detect computer model - $($_.Exception.Message)"
    exit 1
}

# --- 2. Check Support & Determine Model Type ---
$IsSupported = $false
$ModelType = $null

foreach ($SupportedModel in $SupportedModels) {
    if ($ComputerModel -like "*$SupportedModel*") { 
        $IsSupported = $true
        
        # Determine model type based on detected model
        if ($SupportedModel -eq "4852E70" -or $SupportedModel -eq "4852570") {
            $ModelType = "E70"
        } elseif ($ComputerModel -like "*85*") {
            $ModelType = "E85"
        } else {
            $ModelType = "E86"
        }
        break 
    }
}

if (-not $IsSupported) {
    Write-Output "ERROR: Incompatible Model: $ComputerModel"
    Write-Output "Supported Models: $($SupportedModels -join ', ')"
    Write-Output "Script aborted."
    exit 1
}

Write-Output "Model Type: $ModelType"

# --- 3. Determine OS Architecture (v2.0 Compatible) ---
try {
    $OS = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
    $OSArch = $OS.OSArchitecture
    
    if ($OSArch -like "*64*") {
        $Is64Bit = $true
        Write-Output "Architecture: 64-bit"
    } else {
        $Is64Bit = $false
        Write-Output "Architecture: 32-bit"
    }
} catch {
    Write-Output "ERROR: Failed to detect OS architecture - $($_.Exception.Message)"
    exit 1
}

# --- 4. Set Paths Based on Model Type ---
switch ($ModelType) {
    "E70" {
        $FolderName = "BiosTool"
        $ConfigFile = "BiosGoodConfig.txt"
        
        if ($Is64Bit) {
            $SourcePath = Join-Path $SourcePathE70 "wnvram64"
            $ExeName = "SCEWIN_64.exe"
        } else {
            $SourcePath = Join-Path $SourcePathE70 "wnvram"
            $ExeName = "SCEWIN.exe"
        }
        $ExeArgs = "/i /s `"$ConfigFile`" /q"
    }
    "E85" {
        $SourcePath = $SourcePathE85
        $FolderName = "Toshiba_E85_BiosTool"
        $ConfigFile = "E85_Config_Good_v250.sh"
        $ExeName = if ($Is64Bit) { "wnvram64.exe" } else { "wnvram.exe" }
        $ExeArgs = "-u `"$ConfigFile`""
    }
    "E86" {
        $SourcePath = $SourcePathE86
        $FolderName = "Toshiba_E86_BiosTool"
        $ConfigFile = "E86_Config_Good_v280.txt"
        $ExeName = if ($Is64Bit) { "wnvram64.exe" } else { "wnvram.exe" }
        $ExeArgs = "-u `"$ConfigFile`""
    }
    default {
        Write-Output "ERROR: Unknown model type: $ModelType"
        exit 1
    }
}

$DestinationPath = Join-Path $DestinationRoot $FolderName
$script:LogFile = Join-Path $DestinationPath "BIOS_Update.log"

Write-Output "Source Path: $SourcePath"
Write-Output "Destination: $DestinationPath"

# --- 5. Validate Source Path ---
if (-not (Test-Path $SourcePath)) { 
    Write-Output "ERROR: Network source path is unreachable: $SourcePath"
    Write-Output "Please verify network connectivity and path accessibility."
    exit 1
}

# --- 6. File Operations ---
if (Test-Path $DestinationPath) {
    try { 
        Remove-Item -Path $DestinationPath -Recurse -Force -ErrorAction Stop 
        Write-Output "Cleared existing folder: $DestinationPath"
    } catch {
        Write-Output "Warning: Could not clear existing folder, attempting to overwrite."
        Write-Output "Reason: $($_.Exception.Message)"
    }
}

try {
    # Create destination folder
    $null = New-Item -Path $DestinationPath -ItemType Directory -Force -ErrorAction Stop
    
    # Copy files with progress indication
    Write-Output "Copying files from network share..."
    Copy-Item -Path "$SourcePath\*" -Destination $DestinationPath -Recurse -Force -ErrorAction Stop
    Write-Log "Files copied successfully to $DestinationPath"
} catch {
    Write-Output "ERROR: Copy operation failed - $($_.Exception.Message)"
    Write-Output "Source: $SourcePath"
    Write-Output "Destination: $DestinationPath"
    exit 1
}

# --- 7. Validate Required Files ---
$ExePath = Join-Path $DestinationPath $ExeName
$ConfigPath = Join-Path $DestinationPath $ConfigFile

if (-not (Test-Path $ExePath)) {
    Write-Log "ERROR: BIOS executable not found: $ExePath"
    Write-Output "Expected file: $ExeName"
    Write-Output "Location: $DestinationPath"
    exit 1
}

if (-not (Test-Path $ConfigPath)) {
    Write-Log "ERROR: BIOS configuration file not found: $ConfigPath"
    Write-Output "Expected file: $ConfigFile"
    Write-Output "Location: $DestinationPath"
    exit 1
}

Write-Output "Validation passed: All required files present"

# --- 8. Apply BIOS Configuration ---
Write-Log "Applying BIOS configuration: $ExeName $ExeArgs"
Write-Output "--------------------------------------------------"
Write-Output "Executing BIOS update tool..."

try {
    # Change to destination directory for execution
    Set-Location $DestinationPath
    
    # Configure process with isolated execution (prevents FileStream errors)
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $ExePath
    $pinfo.Arguments = $ExeArgs
    $pinfo.UseShellExecute = $false
    $pinfo.WorkingDirectory = $DestinationPath
    $pinfo.CreateNoWindow = $true
    
    # CRITICAL: Disable output redirection to prevent PS v2.0 FileStream handle conflicts
    $pinfo.RedirectStandardOutput = $false
    $pinfo.RedirectStandardError = $false
    
    # Start process
    $p = [System.Diagnostics.Process]::Start($pinfo)
    
    # Validate process started successfully
    if ($p -eq $null) {
        Write-Log "ERROR: Failed to start BIOS tool process"
        Write-Output "Process start failed for: $ExePath"
        exit 1
    }
    
    # Wait for completion
    $p.WaitForExit()
    $ExitCode = $p.ExitCode
    
    # Dispose process object
    $p.Dispose()

    Write-Output "--------------------------------------------------"
    Write-Log "BIOS tool completed with Exit Code: $ExitCode"

    # Evaluate exit code
    if ($ExitCode -eq 0) {
        Write-Log "SUCCESS: BIOS configuration applied successfully"
        Write-Output "=========================================="
        Write-Output "BIOS Configuration Update: SUCCESS"
        Write-Output "=========================================="
        Write-Output ""
        Write-Output "The BIOS settings have been updated."
        Write-Output "Changes will take effect after the next reboot."
        Write-Output ""
        Write-Output "Log file: $script:LogFile"
        Write-Output "=========================================="
        exit 0
    } else {
        Write-Log "FAILED: BIOS tool returned non-zero exit code: $ExitCode"
        Write-Output "=========================================="
        Write-Output "BIOS Configuration Update: FAILED"
        Write-Output "=========================================="
        Write-Output "Exit Code: $ExitCode"
        Write-Output "Check log file for details: $script:LogFile"
        Write-Output "=========================================="
        exit $ExitCode
    }
    
} catch {
    Write-Log "CRITICAL ERROR: Exception during BIOS update - $($_.Exception.Message)"
    Write-Output "=========================================="
    Write-Output "CRITICAL ERROR"
    Write-Output "=========================================="
    Write-Output "Error: $($_.Exception.Message)"
    Write-Output "Stack Trace: $($_.Exception.StackTrace)"
    Write-Output "=========================================="
    exit 1
}

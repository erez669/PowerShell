<#
.SYNOPSIS
    Toshiba POS BIOS Configuration Deployment Script
.DESCRIPTION
    Detects Toshiba POS model, copies BIOS tools, and applies configuration.
    Fully compatible with PowerShell v2.0 and NT AUTHORITY\SYSTEM.
    Written by Erez Schwartz
.NOTES
    Version: 1.6
    - Removed: Ternary operators and PS 3.0+ commands.
    - Fixed: FileStream handle errors by using .NET Process start.
    - Fixed: Removed auto-reboot; added success message.
    - Fixed: Uses Get-WmiObject for v2.0 compatibility.
#>

# --- Variables ---
$SourcePathE85 = "\\myserver\myshare\Packages\POS\BiosUpdate\Toshiba_E85_BiosTool"
$SourcePathE86 = "\\myserver\myshare\Packages\POS\BiosUpdate\Toshiba_E86_BiosTool"
$DestinationRoot = "D:\"
$SupportedModels = @("4900E85", "4900785", "4900786", "4900E86")

# --- Logging Function ---
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    
    # Standard output for Ivanti logs
    Write-Output $logMessage
    
    if ($script:LogFile) {
        $logDir = Split-Path $script:LogFile
        if (Test-Path $logDir) {
            # Out-File is safer for v2.0 handles than Add-Content
            $logMessage | Out-File -FilePath $script:LogFile -Append -Encoding UTF8
        }
    }
}

Write-Output "=========================================="
Write-Output "BIOS Configuration Deployment Started"
Write-Output "=========================================="

# --- 1. Identify System (v2.0 Compatible) ---
try {
    $ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $ComputerModel = $ComputerSystem.Model
    Write-Output "Detected Model: $ComputerModel"
} catch {
    Write-Output "ERROR: Failed to detect computer model - $($_.Exception.Message)"
    exit 1
}

# --- 2. Check Support & Set Paths ---
$IsSupported = $false
foreach ($SupportedModel in $SupportedModels) {
    if ($ComputerModel -like "*$SupportedModel*") { 
        $IsSupported = $true
        break 
    }
}

if (-not $IsSupported) {
    Write-Output "ERROR: Incompatible Model: $ComputerModel. Script aborted."
    exit 1
}

# Determine OS Architecture (v2.0 Compatible)
$OS = Get-WmiObject -Class Win32_OperatingSystem
$OSArch = $OS.OSArchitecture

if ($OSArch -like "*64*") {
    $ExeName = "wnvram64.exe"
} else {
    $ExeName = "wnvram.exe"
}

# Select source and config based on model series
if ($ComputerModel -like "*85*") {
    $SourcePath = $SourcePathE85
    $FolderName = "Toshiba_E85_BiosTool"
    $ConfigFile = "E85_Config_Good_v250.sh"
} else {
    $SourcePath = $SourcePathE86
    $FolderName = "Toshiba_E86_BiosTool"
    $ConfigFile = "E86_Config_Good_v280.txt"
}

$DestinationPath = Join-Path $DestinationRoot $FolderName
$script:LogFile = Join-Path $DestinationPath "BIOS_Update.log"

# --- 3. File Operations ---
if (Test-Path $DestinationPath) {
    try { 
        Remove-Item -Path $DestinationPath -Recurse -Force -ErrorAction Stop 
    } catch {
        Write-Output "Note: Could not clear existing folder, attempting to overwrite."
    }
}

try {
    if (-not (Test-Path $SourcePath)) { 
        Write-Output "ERROR: Network source path $SourcePath is unreachable."
        exit 1
    }
    Copy-Item -Path $SourcePath -Destination $DestinationPath -Recurse -Force -ErrorAction Stop
    Write-Log "Files copied successfully to $DestinationPath"
} catch {
    Write-Output "ERROR: Copy failed - $($_.Exception.Message)"
    exit 1
}

# --- 4. Apply BIOS Configuration ---
$ExePath = Join-Path $DestinationPath $ExeName
$ConfigPath = Join-Path $DestinationPath $ConfigFile

if (-not (Test-Path $ExePath) -or -not (Test-Path $ConfigPath)) {
    Write-Log "ERROR: Missing required files in $DestinationPath"
    exit 1
}

Write-Log "Applying BIOS configuration: $ExeName -u $ConfigFile"

try {
    Set-Location $DestinationPath
    
    # Manually creating ProcessStartInfo for maximum control in PS v2.0 / SYSTEM account
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $ExePath
    $pinfo.Arguments = "-u `"$ConfigFile`""
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $pinfo.RedirectStandardOutput = $false
    $pinfo.WorkingDirectory = $DestinationPath
    
    $p = [System.Diagnostics.Process]::Start($pinfo)
    $p.WaitForExit()
    $ExitCode = $p.ExitCode

    if ($ExitCode -eq 0) {
        Write-Log "SUCCESS: BIOS configuration applied successfully."
        Write-Output "--------------------------------------------------"
        Write-Output "BIOS configuration updated successfully."
        Write-Output "Changes will take effect after the next reboot."
        Write-Output "--------------------------------------------------"
        exit 0
    } else {
        Write-Log "FAILED: BIOS tool returned Exit Code: $ExitCode"
        exit $ExitCode
    }
} catch {
    Write-Log "CRITICAL ERROR: $($_.Exception.Message)"
    exit 1
}

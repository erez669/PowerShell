# Win11Upgrade-InPlace.ps1
# Simplified Windows 11 In-Place Upgrade Script with Robust Compatibility Checks
# Last updated: 2025-08-18 - FIXED TPM CHECK
# Usage: Execute with administrator privileges

# Configuration paths
$SourcePath = "\\10.250.236.25\IvantiShare\PackagesMarlogMifalim\Win11Upgrade"
$InstallPath = "C:\Install\OSUpgrade"
$LogPath = "C:\Temp\Win11UpgradeLogs"
$logFilePath = Join-Path -Path $LogPath -ChildPath "Win11Upgrade_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

#region Functions
function Write-LogMessage {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Try to write to log file with error handling and mutex
    try {
        # Use mutex to prevent concurrent access
        $mutex = New-Object System.Threading.Mutex($false, "Win11UpgradeLogMutex")
        $mutex.WaitOne(1000) | Out-Null  # Wait up to 1 second
        
        # Use Out-File with -Append (creates file if doesn't exist, appends if exists)
        $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8 -ErrorAction Stop
        
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
    catch {
        # If logging fails, continue without crashing
        Write-Host "WARNING: Could not write to log file: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Always display to console regardless of log file success
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
    }
}

function Exit-ScriptWithMessage {
    param (
        [int]$ExitCode,
        [string]$Message,
        [string]$Level = "ERROR"
    )
    
    Write-LogMessage $Message -Level $Level
    Write-LogMessage "Exiting script with exit code: $ExitCode" -Level $Level
    exit $ExitCode
}

function Backup-HostsFile {
    Write-LogMessage "=== Backing up hosts file ===" -Level "INFO"
    
    $hostsPath = Join-Path -Path $env:windir -ChildPath "System32\drivers\etc\hosts"
    $backupDir = "C:\temp\hosts-backup"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFileName = "hosts_backup_$timestamp"
    $backupPath = Join-Path -Path $backupDir -ChildPath $backupFileName
    
    Write-LogMessage "Hosts file location: $hostsPath" -Level "INFO"
    Write-LogMessage "Backup directory: $backupDir" -Level "INFO"
    
    # Create backup directory if it doesn't exist
    if (!(Test-Path $backupDir)) {
        try {
            New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
            Write-LogMessage "Created backup directory: $backupDir" -Level "INFO"
        }
        catch {
            Exit-ScriptWithMessage -ExitCode 1 -Message "Error creating hosts backup directory: $_" -Level "ERROR"
        }
    }
    
    # Check if hosts file exists
    if (!(Test-Path $hostsPath)) {
        Write-LogMessage "Warning: Hosts file not found at $hostsPath" -Level "WARNING"
        return
    }
    
    # Backup the hosts file
    try {
        Copy-Item -Path $hostsPath -Destination $backupPath -Force
        Write-LogMessage "Hosts file backed up successfully to: $backupPath" -Level "SUCCESS"
        
        # Verify backup
        if (Test-Path $backupPath) {
            $originalSize = (Get-Item $hostsPath).Length
            $backupSize = (Get-Item $backupPath).Length
            
            if ($originalSize -eq $backupSize) {
                Write-LogMessage "Backup verification successful (Size: $originalSize bytes)" -Level "SUCCESS"
            } else {
                Write-LogMessage "Warning: Backup size mismatch. Original: $originalSize, Backup: $backupSize" -Level "WARNING"
            }
        } else {
            Exit-ScriptWithMessage -ExitCode 1 -Message "Backup verification failed - backup file not found" -Level "ERROR"
        }
    }
    catch {
        Exit-ScriptWithMessage -ExitCode 1 -Message "Error backing up hosts file: $_" -Level "ERROR"
    }
}

function Initialize-Script {
    # Check if admin
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "This script requires administrative privileges. Please restart as administrator." -ForegroundColor Red
        exit 1
    }

    # Create log directory (Out-File -Append will create the log file automatically)
    if (!(Test-Path $LogPath)) {
        try {
            New-Item -ItemType Directory -Force -Path $LogPath | Out-Null
        }
        catch {
            Write-Host "Error creating log directory: $_" -ForegroundColor Red
            exit 1
        }
    }
    
    # Log script start and basic info (this will create the log file automatically)
    Write-LogMessage "===== Windows 11 Upgrade Script Started =====" -Level "INFO"
    Write-LogMessage "Script execution path: $PSScriptRoot" -Level "INFO"
    Write-LogMessage "Source path: $SourcePath" -Level "INFO"
    Write-LogMessage "Installation path: $InstallPath" -Level "INFO"
    Write-LogMessage "Log file path: $logFilePath" -Level "INFO"
    
    # Log system info
    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $systemDrive = Get-PSDrive -Name $env:SystemDrive.TrimEnd(':')
        $freeSpaceGB = [math]::Round($systemDrive.Free / 1GB, 2)
        
        Write-LogMessage "OS: $($osInfo.Caption) $($osInfo.Version)" -Level "INFO"
        Write-LogMessage "Computer: $($computerSystem.Name) | Domain: $($computerSystem.Domain)" -Level "INFO"
        Write-LogMessage "Free space: $freeSpaceGB GB" -Level "INFO"
        Write-LogMessage "Current User: $([System.Environment]::UserName)" -Level "INFO"
    }
    catch {
        Write-LogMessage "Warning: Could not retrieve some system information: $_" -Level "WARNING"
    }
}

function Test-Win11Compatibility {
    Write-LogMessage "=== Testing Windows 11 Compatibility ===" -Level "INFO"
    
    $failures = @()
    $warnings = @()
    
    # 1. Check current OS
    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        Write-LogMessage "Current OS: $($osInfo.Caption) Version $($osInfo.Version)" -Level "INFO"
        
        if ($osInfo.Caption -like "*Windows 11*") {
            Exit-ScriptWithMessage -ExitCode 15 -Message "Machine is already running Windows 11. No upgrade needed." -Level "WARNING"
        } elseif ($osInfo.Caption -like "*Windows 10*") {
            Write-LogMessage "PASS: Running Windows 10 (can upgrade to Win11)" -Level "SUCCESS"
        } else {
            Write-LogMessage "FAIL: Not running Windows 10/11: $($osInfo.Caption)" -Level "ERROR"
            $failures += "Operating System not compatible"
        }
    }
    catch {
        Write-LogMessage "FAIL: Error checking OS: $_" -Level "ERROR"
        $failures += "Could not determine OS"
    }
    
    # 2. Check Windows 10 build (More flexible than original)
    try {
        $buildNumber = [int](Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CurrentBuildNumber" -ErrorAction Stop).CurrentBuildNumber
        $releaseId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
        $ubr = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "UBR" -ErrorAction SilentlyContinue).UBR
        
        $fullVersion = "$buildNumber"
        if ($ubr) { $fullVersion += ".$ubr" }
        if ($releaseId) { $fullVersion += " ($releaseId)" }
        
        Write-LogMessage "Windows build: $fullVersion" -Level "INFO"
        
        # Accept any Windows 10 build 19041+ (20H1 and later) instead of just 22H2
        if ($buildNumber -ge 19041) {
            Write-LogMessage "PASS: Windows 10 build $buildNumber is compatible (19041+ required)" -Level "SUCCESS"
        } else {
            Write-LogMessage "FAIL: Windows 10 build $buildNumber is too old (19041+ required)" -Level "ERROR"
            $failures += "Windows 10 build too old"
        }
    }
    catch {
        Write-LogMessage "FAIL: Error checking Windows build: $_" -Level "ERROR"
        $failures += "Could not determine Windows build"
    }
    
    # 3. Check UEFI/BIOS mode (Robust)
    Write-LogMessage "Checking boot mode..." -Level "INFO"
    try {
        $firmwareType = $env:firmware_type
        Write-LogMessage "Firmware type: $firmwareType" -Level "INFO"
        
        if ($firmwareType -eq "UEFI") {
            Write-LogMessage "PASS: UEFI boot mode detected" -Level "SUCCESS"
        } else {
            Write-LogMessage "FAIL: Legacy BIOS detected (UEFI required)" -Level "ERROR"
            $failures += "Legacy BIOS (UEFI required)"
        }
    }
    catch {
        Write-LogMessage "WARN: Could not determine firmware type" -Level "WARNING"
        $warnings += "Could not verify firmware type"
    }
    
    # 4. Check Secure Boot (Warning only, not critical)
    Write-LogMessage "Checking Secure Boot..." -Level "INFO"
    try {
        $secureBootEnabled = Confirm-SecureBootUEFI
        if ($secureBootEnabled) {
            Write-LogMessage "PASS: Secure Boot is enabled" -Level "SUCCESS"
        } else {
            Write-LogMessage "WARN: Secure Boot is disabled" -Level "WARNING"
            $warnings += "Secure Boot disabled"
        }
    }
    catch {
        Write-LogMessage "WARN: Secure Boot verification failed" -Level "WARNING"
        $warnings += "Secure Boot not available/enabled"
    }
    
    # 5. Check TPM 2.0 (FIXED - using correct property names)
    Write-LogMessage "Checking TPM 2.0..." -Level "INFO"
    try {
        # Get TPM status using Get-Tpm
        $getTpmResult = Get-Tpm -ErrorAction Stop
        
        # Capture the exact properties from Get-Tpm - ALL properties use "Tpm" not "Tmp"
        $tpmPresent = $getTpmResult.TpmPresent      # Fixed: was TpmPresent 
        $tpmReady = $getTpmResult.TpmReady          # Fixed: was TpmReady 
        $tpmEnabled = $getTpmResult.TpmEnabled      # FIXED: was TmpEnabled (typo)
        $tpmActivated = $getTpmResult.TpmActivated  # FIXED: was TmpActivated (typo)
        
        Write-LogMessage "TPM Status: Present=$tpmPresent, Ready=$tpmReady, Enabled=$tpmEnabled, Activated=$tpmActivated" -Level "INFO"
        
        # Get TPM version using CIM
        $cimTpm = Get-CimInstance -Namespace "Root\CimV2\Security\MicrosoftTpm" -ClassName "Win32_Tpm" -ErrorAction Stop
        $specVersion = $cimTpm.SpecVersion
        $isActivatedCim = $cimTpm.IsActivated_InitialValue
        $isEnabledCim = $cimTpm.IsEnabled_InitialValue
        
        # Clean up the version display - just show main version (1.2 or 2.0)
        $specVersionDisplay = if ($specVersion) { $specVersion.Split(',')[0].Trim() } else { $specVersion }
        
        Write-LogMessage "TPM CIM Details: SpecVersion=$specVersionDisplay, Activated=$isActivatedCim, Enabled=$isEnabledCim" -Level "INFO"
        
        # Check if TPM 2.0 and ready
        if ($specVersion -like "2.0*") {
            if ($tpmPresent -and $tpmReady -and $tpmEnabled -and $tpmActivated) {
                Write-LogMessage "PASS: TPM 2.0 detected and ready (Version: $specVersionDisplay)" -Level "SUCCESS"
            } else {
                Write-LogMessage "FAIL: TPM 2.0 present but not ready" -Level "ERROR"
                Write-LogMessage "  TPM Details: Present=$tpmPresent, Ready=$tpmReady, Enabled=$tpmEnabled, Activated=$tpmActivated" -Level "ERROR"
                $failures += "TPM 2.0 not ready"
            }
        } else {
            Write-LogMessage "FAIL: TPM present but not version 2.0 (Found: $specVersionDisplay)" -Level "ERROR"
            $failures += "TPM version not 2.0"
        }
    }
    catch {
        Write-LogMessage "FAIL: TPM check failed: $_" -Level "ERROR"
        $failures += "TPM verification failed"
    }
    
    # 6. Check CPU (Basic requirements)
    Write-LogMessage "Checking CPU..." -Level "INFO"
    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor
        Write-LogMessage "CPU: $($cpu.Name)" -Level "INFO"
        
        # Check 64-bit
        if ($cpu.AddressWidth -eq 64) {
            Write-LogMessage "PASS: 64-bit CPU" -Level "SUCCESS"
        } else {
            Write-LogMessage "FAIL: 32-bit CPU (64-bit required)" -Level "ERROR"
            $failures += "32-bit CPU"
        }
        
        # Check cores
        if ($cpu.NumberOfCores -ge 2) {
            Write-LogMessage "PASS: $($cpu.NumberOfCores) CPU cores (2+ required)" -Level "SUCCESS"
        } else {
            Write-LogMessage "FAIL: Only $($cpu.NumberOfCores) CPU core (2+ required)" -Level "ERROR"
            $failures += "Insufficient CPU cores"
        }
        
        # Check speed
        $speedGHz = [math]::Round($cpu.MaxClockSpeed / 1000, 1)
        if ($speedGHz -ge 1.0) {
            Write-LogMessage "PASS: CPU speed: $speedGHz GHz (1+ GHz required)" -Level "SUCCESS"
        } else {
            Write-LogMessage "FAIL: CPU speed: $speedGHz GHz (1+ GHz required)" -Level "ERROR"
            $failures += "CPU too slow"
        }
    }
    catch {
        Write-LogMessage "WARN: Could not fully check CPU: $_" -Level "WARNING"
        $warnings += "CPU verification incomplete"
    }
    
    # 7. Check RAM
    Write-LogMessage "Checking memory..." -Level "INFO"
    try {
        $memory = Get-CimInstance -ClassName Win32_PhysicalMemory
        $totalRAM = [math]::Round(($memory | Measure-Object -Property Capacity -Sum).Sum / 1GB, 1)
        
        if ($totalRAM -ge 4) {
            Write-LogMessage "PASS: $totalRAM GB RAM (4+ GB required)" -Level "SUCCESS"
        } else {
            Write-LogMessage "FAIL: $totalRAM GB RAM (4+ GB required)" -Level "ERROR"
            $failures += "Insufficient RAM"
        }
    }
    catch {
        Write-LogMessage "WARN: Could not check RAM: $_" -Level "WARNING"
        $warnings += "RAM verification failed"
    }
    
    # 8. Test network path (existing check from original)
    Write-LogMessage "Testing network path accessibility..." -Level "INFO"
    if (Test-Path $SourcePath) {
        # Also check if setup.exe exists
        $setupPath = Join-Path -Path $SourcePath -ChildPath "setup.exe"
        if (Test-Path $setupPath) {
            Write-LogMessage "PASS: Network path accessible and setup.exe found" -Level "SUCCESS"
        } else {
            Write-LogMessage "FAIL: Network path accessible but setup.exe missing" -Level "ERROR"
            $failures += "Setup.exe missing from network path"
        }
    } else {
        Write-LogMessage "FAIL: Cannot access source network path: $SourcePath" -Level "ERROR"
        $failures += "Network path not accessible"
    }
    
    # 9. Test disk space (existing check from original)
    Write-LogMessage "Checking storage..." -Level "INFO"
    try {
        $systemDrive = Get-PSDrive -Name $env:SystemDrive.TrimEnd(':')
        $freeSpaceGB = [math]::Round($systemDrive.Free / 1GB, 1)
        $totalSpaceGB = [math]::Round(($systemDrive.Used + $systemDrive.Free) / 1GB, 1)
        
        if ($totalSpaceGB -ge 64) {
            Write-LogMessage "PASS: $totalSpaceGB GB total storage (64+ GB required)" -Level "SUCCESS"
        } else {
            Write-LogMessage "FAIL: $totalSpaceGB GB total storage (64+ GB required)" -Level "ERROR"
            $failures += "Insufficient storage space"
        }
        
        if ($freeSpaceGB -ge 20) {
            Write-LogMessage "PASS: $freeSpaceGB GB free space (20+ GB required)" -Level "SUCCESS"
        } else {
            Write-LogMessage "FAIL: $freeSpaceGB GB free space (20+ GB required)" -Level "ERROR"
            $failures += "Insufficient free disk space"
        }
    }
    catch {
        Write-LogMessage "WARN: Could not check storage: $_" -Level "WARNING"
        $warnings += "Storage verification failed"
    }
    
    # 10. Check for pending reboots
    Write-LogMessage "Checking for pending reboots..." -Level "INFO"
    try {
        $pendingReboot = $false
        
        # Check Windows Update reboot pending
        if (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) {
            $pendingReboot = $true
        }
        
        # Check Component Based Servicing reboot pending
        if (Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue) {
            $pendingReboot = $true
        }
        
        # Check PendingFileRenameOperations
        $pendingFileRename = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
        if ($pendingFileRename) {
            $pendingReboot = $true
        }
        
        if ($pendingReboot) {
            Write-LogMessage "WARN: Pending reboot detected - recommend restarting before upgrade" -Level "WARNING"
            $warnings += "Pending reboot detected"
        } else {
            Write-LogMessage "PASS: No pending reboots detected" -Level "SUCCESS"
        }
    }
    catch {
        Write-LogMessage "WARN: Could not check pending reboot status: $_" -Level "WARNING"
        $warnings += "Pending reboot check failed"
    }
    
    # 11. Check BitLocker status
    Write-LogMessage "Checking BitLocker status..." -Level "INFO"
    try {
        $bitlockerVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue
        if ($bitlockerVolume) {
            if ($bitlockerVolume.ProtectionStatus -eq "On") {
                Write-LogMessage "WARN: BitLocker is enabled - ensure recovery key is documented before upgrade" -Level "WARNING"
                $warnings += "BitLocker enabled - ensure recovery key is available"
            } else {
                Write-LogMessage "PASS: BitLocker present but not active" -Level "SUCCESS"
            }
        } else {
            Write-LogMessage "PASS: BitLocker not detected" -Level "SUCCESS"
        }
    }
    catch {
        # BitLocker cmdlets not available or no BitLocker
        Write-LogMessage "PASS: BitLocker check completed (likely not present)" -Level "SUCCESS"
    }
    
    # Summary
    Write-LogMessage "=== COMPATIBILITY SUMMARY ===" -Level "INFO"
    Write-LogMessage "Critical failures: $($failures.Count)" -Level "INFO"
    Write-LogMessage "Warnings: $($warnings.Count)" -Level "INFO"
    
    if ($failures.Count -gt 0) {
        Write-LogMessage "RESULT: Critical compatibility checks FAILED" -Level "ERROR"
        Write-LogMessage "Critical issues found:" -Level "ERROR"
        foreach ($failure in $failures) {
            Write-LogMessage "  - $failure" -Level "ERROR"
        }
        Exit-ScriptWithMessage -ExitCode 20 -Message "System does not meet Windows 11 requirements. See log for details." -Level "ERROR"
    } else {
        if ($warnings.Count -gt 0) {
            Write-LogMessage "RESULT: All critical checks PASSED, but $($warnings.Count) warning(s) detected" -Level "WARNING"
            Write-LogMessage "Warnings found:" -Level "WARNING"
            foreach ($warning in $warnings) {
                Write-LogMessage "  - $warning" -Level "WARNING"
            }
            Write-LogMessage "Recommendation: Address warnings if possible, but upgrade can proceed" -Level "WARNING"
        } else {
            Write-LogMessage "RESULT: All compatibility checks PASSED - Ready for upgrade!" -Level "SUCCESS"
        }
    }
}

function Copy-InstallFiles {
    Write-LogMessage "=== Starting file copy phase ===" -Level "INFO"
    Write-LogMessage "Copying Windows 11 installation files..." -Level "INFO"
    
    # Clean/create destination
    if (Test-Path $InstallPath) {
        try {
            Remove-Item -Path $InstallPath -Recurse -Force
            Write-LogMessage "Cleaned existing installation directory" -Level "INFO"
        }
        catch {
            Exit-ScriptWithMessage -ExitCode 1 -Message "Error cleaning directory: $_" -Level "ERROR"
        }
    }
    
    try {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        Write-LogMessage "Created installation directory: $InstallPath" -Level "INFO"
    }
    catch {
        Exit-ScriptWithMessage -ExitCode 1 -Message "Error creating installation directory: $_" -Level "ERROR"
    }
    
    # Robocopy with better logging
    $robocopyLog = Join-Path -Path $LogPath -ChildPath "robocopy_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $robocopyArgs = @(
        $SourcePath,
        $InstallPath,
        "/E", "/Z", "/W:1", "/R:3", "/NP", "/MT:8", "/LOG+:$robocopyLog"
    )
    
    Write-LogMessage "Robocopy command: robocopy.exe $($robocopyArgs -join ' ')" -Level "INFO"
    Write-LogMessage "Robocopy log file: $robocopyLog" -Level "INFO"
    
    try {
        $process = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -NoNewWindow -PassThru -Wait
        
        Write-LogMessage "Robocopy completed with exit code: $($process.ExitCode)" -Level "INFO"
        
        # Check success (codes 0-7 are success for robocopy)
        if ($process.ExitCode -ge 8) {
            Exit-ScriptWithMessage -ExitCode 1 -Message "Robocopy failed with code: $($process.ExitCode). Check log: $robocopyLog" -Level "ERROR"
        }
        
        # Verify setup.exe
        $setupPath = Join-Path -Path $InstallPath -ChildPath "setup.exe"
        if (!(Test-Path $setupPath)) {
            Exit-ScriptWithMessage -ExitCode 1 -Message "Setup.exe not found after copying files. Expected at: $setupPath" -Level "ERROR"
        }
        
        Write-LogMessage "Installation files copied successfully" -Level "SUCCESS"
        Write-LogMessage "Setup.exe verified at: $setupPath" -Level "INFO"
        return $setupPath
    }
    catch {
        Exit-ScriptWithMessage -ExitCode 1 -Message "Error during file copy: $_" -Level "ERROR"
    }
}

function Start-UpgradeProcess {
    param (
        [string]$SetupPath
    )
    
    Write-LogMessage "=== Starting upgrade phase ===" -Level "INFO"
    Write-LogMessage "Starting Windows 11 upgrade process..." -Level "INFO"
    
    $setupArgs = "/Auto Upgrade /quiet /noreboot /DynamicUpdate Disable /showoobe none /Compat IgnoreWarning /eula accept /product server"
    Write-LogMessage "Setup arguments: $setupArgs" -Level "INFO"
    Write-LogMessage "Full command: `"$SetupPath`" $setupArgs" -Level "INFO"
    Write-LogMessage "This process may take 30-60 minutes. Please be patient and do not interrupt." -Level "WARNING"
    
    try {
        Write-LogMessage "Executing setup.exe now - upgrade process starting..." -Level "INFO"
        $startTime = Get-Date
        
        # Start the upgrade process
        $process = Start-Process -FilePath $SetupPath -ArgumentList $setupArgs -NoNewWindow -PassThru -Wait
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-LogMessage "Setup.exe process completed after $([math]::Round($duration.TotalMinutes, 2)) minutes" -Level "INFO"
        Write-LogMessage "Setup.exe exit code: $($process.ExitCode)" -Level "INFO"
        
        if ($process.ExitCode -ne 0) {
            Exit-ScriptWithMessage -ExitCode 1 -Message "Setup failed with exit code: $($process.ExitCode)" -Level "ERROR"
        }
        
        Write-LogMessage "Windows 11 upgrade completed successfully" -Level "SUCCESS"
        Write-LogMessage "System will restart in 10 seconds to finalize the upgrade" -Level "WARNING"
        
        # Final log message before restart
        Write-LogMessage "Initiating system restart..." -Level "INFO"
        Write-LogMessage "===== Script completed successfully - System restarting =====" -Level "SUCCESS"
        
        # Restart system
        shutdown -r -t 10 -f
    }
    catch {
        Exit-ScriptWithMessage -ExitCode 1 -Message "Error during upgrade: $_" -Level "ERROR"
    }
}
#endregion

try {
    # Initialize everything
    Initialize-Script

    # Backup hosts file BEFORE any other operations
    Backup-HostsFile

    # Robust compatibility check (replaces Test-EnhancedRequirements)
    Test-Win11Compatibility

    # Copy installation files
    $setupPath = Copy-InstallFiles

    # Start upgrade
    Start-UpgradeProcess -SetupPath $setupPath

    # Exit successfully (should not reach here due to shutdown)
    exit 0
}
catch {
    Write-LogMessage "Unhandled error in main script: $_" -Level "ERROR"
    Write-LogMessage "Script execution failed" -Level "ERROR"
    exit 1
}
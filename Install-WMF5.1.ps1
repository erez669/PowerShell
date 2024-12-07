[CmdletBinding(SupportsShouldProcess=$true)]
param ()

Clear-Host
$ErrorActionPreference = 'Stop'
$TargetKB = "KB3191566"
$LogPath = "C:\Temp"
$LogFile = Join-Path -Path $LogPath -ChildPath "WMF51_Installation_Summary.txt"
$DismLogFile = Join-Path -Path $LogPath -ChildPath "DISM_WMF51_Install.log"
$global:exitCode = 0  # Initialize a global variable for exit code

# Get the actual .NET version from registry
$global:netVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Version
if (-not $global:netVersion) {
    $global:netVersion = $PSVersionTable.CLRVersion.ToString()
}

# Ensure log directory exists
if (-not (Test-Path -Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Remove existing log files
if (Test-Path -Path $LogFile) { Remove-Item -Path $LogFile -Force }
if (Test-Path -Path $DismLogFile) { Remove-Item -Path $DismLogFile -Force }

# Function to write to console and log
function Write-LogMessage {
    param(
        [Parameter(Mandatory=$true)][string]$Message = "No message provided",
        [ValidateSet('Information', 'Warning', 'Error', 'Success')][string]$Type = 'Information'
    )
    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    $logMessage = "[$timestamp] $Type - $Message"
    Add-Content -Path $LogFile -Value $logMessage
    switch ($Type) {
        'Information' { Write-Host $logMessage -ForegroundColor White }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error' { Write-Host $logMessage -ForegroundColor Red }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
    }
}

# prerequisite .NET Framework check
$dotNetCheckScript = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath "Check-DotNet.ps1"
if (Test-Path $dotNetCheckScript) {
    Write-LogMessage "Checking .NET Framework version..." -Type Information
    $dotNetResult = & $dotNetCheckScript
    if ($LASTEXITCODE -ne 0) {
        Write-LogMessage ".NET Framework version $global:netVersion is insufficient." -Type Error
        Write-Host ""
        Write-LogMessage "Attempting to install .NET Framework 4.6..." -Type Information
        
        # .NET Framework installation logic
        $netFrameworkPath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath "NDP46-KB3045557-x86-x64-AllOS-ENU.exe"
        if (Test-Path $netFrameworkPath) {
            Write-LogMessage "Installing .NET Framework 4.6..." -Type Information
            $installArgs = "/passive /AcceptEULA /norestart"
            $installProcess = Start-Process -FilePath $netFrameworkPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
            
            if ($installProcess.ExitCode -eq 0 -or $installProcess.ExitCode -eq 3010) {
			Write-LogMessage ".NET Framework 4.6 installation completed. Restart recommended but skipped." -Type Success
			$global:exitCode = 0
		} else {
			Write-LogMessage ".NET Framework 4.6 installation failed with code: $($installProcess.ExitCode)" -Type Error
			$global:exitCode = $installProcess.ExitCode
			exit $global:exitCode
		}
        } else {
            Write-LogMessage ".NET Framework 4.6 installer not found at: $netFrameworkPath" -Type Error
            $global:exitCode = 1
            exit $global:exitCode
        }
    } else {
        Write-Host ""
        Write-LogMessage ".NET Framework version $global:netVersion is compatible" -Type Success
        Write-Host ""
    }
} else {
    Write-LogMessage ".NET Framework version check script not found" -Type Warning
    Write-Host ""
}

# Compatibility Check Function
function Test-Compatibility {
    Write-LogMessage "Checking OS compatibility..." -Type Information
    try {
        $osInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
        $isWin7 = $osInfo.Version -like "6.1*"
        
        # Always show detailed OS information
        Write-LogMessage "Detected OS: $($osInfo.Caption)" -Type Information
        
        if (!$isWin7) {
            Write-LogMessage "Script is designed for Windows 7 only. " -Type Information
            $global:exitCode = 0
            return $false
        }
        
        Write-LogMessage "Windows 7 detected - compatibility check passed." -Type Success
        return $true
    }
    catch {
        Write-LogMessage "Unable to determine OS version." -Type Information
        $global:exitCode = 0
        return $false
    }
}

# KB Installation Check
function Test-KBInstalled {
    param ([string]$KBNumber)
    $hotfix = Get-HotFix -Id $KBNumber -ErrorAction SilentlyContinue
    if ($hotfix) {
        Write-LogMessage "$KBNumber already installed on $(Get-Date -Format 'dd-MM-yyyy HH:mm:ss')." -Type Warning
        $global:exitCode = 0
        return $true
    }
    Write-LogMessage "$KBNumber not found." -Type Information
    return $false
}

# Function to check and enable Windows Update service
function Enable-WindowsUpdateService {
    Write-LogMessage "Checking Windows Update service status..." -Type Information
    try {
        $wuauserv = Get-Service -Name "wuauserv" -ErrorAction Stop
        if ($wuauserv.Status -ne "Running") {
            Write-LogMessage "Windows Update service is not running. Attempting to start..." -Type Warning
            Set-Service -Name "wuauserv" -StartupType Automatic -ErrorAction Stop
            Start-Service -Name "wuauserv" -ErrorAction Stop
            Write-LogMessage "Windows Update service started successfully." -Type Success
        } else {
            Write-LogMessage "Windows Update service is already running." -Type Information
        }
        return $true
    }
    catch {
        Write-LogMessage "Failed to enable Windows Update service: $_" -Type Error
        return $false
    }
}

# Start installation if prerequisites are met
function Start-Installation {
    param ([string]$PackagePath)
    $ExpandPath = Join-Path -Path $env:TEMP -ChildPath "WMF51_Expanded"
    
    if (Test-Path $ExpandPath) { Remove-Item -Path $ExpandPath -Recurse -Force }
    New-Item -Path $ExpandPath -ItemType Directory -Force | Out-Null
    
    Write-LogMessage "Expanding MSU package..." -Type Information
    $expandResult = Start-Process -FilePath "expand.exe" -ArgumentList "`"$PackagePath`" -F:* `"$ExpandPath`"" -Wait -PassThru -NoNewWindow
    if ($expandResult.ExitCode -ne 0) { 
        Write-LogMessage "Expansion failed with exit code $($expandResult.ExitCode)." -Type Error
        return $expandResult.ExitCode
    }

    $cabFile = Get-ChildItem -Path $ExpandPath -Filter "Windows6.1-KB3191566-*.cab" | Select-Object -First 1
    if (-not $cabFile) {
        Write-LogMessage "Expected CAB file for WMF 5.1 not found." -Type Error
        return 2
    }
    
    Write-LogMessage "Installing CAB file: $($cabFile.Name)" -Type Information
    $result = Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Add-Package /PackagePath:`"$($cabFile.FullName)`" /Quiet /NoRestart /LogPath:`"$DismLogFile`" /IgnoreCheck" -Wait -PassThru -WindowStyle Hidden

    # Cleanup expanded files
    if (Test-Path $ExpandPath) {
        Remove-Item -Path $ExpandPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($result.ExitCode -eq 0 -or $result.ExitCode -eq 3010) {
        Write-LogMessage "Installation completed successfully (DISM exit code: $($result.ExitCode))." -Type Success
        $global:exitCode = 0
        Write-LogMessage "Final exit code set to $global:exitCode. System will restart in 15 seconds..." -Type Warning
        Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 15 /f" -WindowStyle Hidden
        Start-Sleep -Seconds 3
        return $global:exitCode
    } else {
        Write-LogMessage "Installation failed (DISM exit code: $($result.ExitCode))." -Type Error
        $global:exitCode = $result.ExitCode
        Write-LogMessage "Final exit code set to $global:exitCode." -Type Error
        return $global:exitCode
    }
}

# Main Execution
Write-LogMessage "Starting WMF 5.1 installation script." -Type Information
try {
    if (Test-KBInstalled -KBNumber $TargetKB) { 
        $global:exitCode = 0
    } else {
        $isCompatible = Test-Compatibility
        if ($isCompatible) {
            # Add Windows Update service check here
            if (Enable-WindowsUpdateService) {
                $packageName = if ($env:PROCESSOR_ARCHITECTURE -eq 'x86') { 
                    'Win7-KB3191566-x86.msu' 
                } else { 
                    'Win7AndW2K8R2-KB3191566-x64.msu' 
                }
                $packagePath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath $packageName
                
                if (Test-Path $packagePath) {
                    $global:exitCode = Start-Installation -PackagePath $packagePath
                } else {
                    Write-LogMessage "Package file $packageName not found." -Type Error
                    $global:exitCode = 3
                }
            } else {
                Write-LogMessage "Cannot proceed with installation - Windows Update service is required." -Type Error
                $global:exitCode = 1
            }
        }
    }
}
catch {
    # Only set error exit code if we're on Windows 7 and something fails
    $isWin7 = (Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption -like "*Windows 7*"
    if ($isWin7) {
        Write-LogMessage "An error occurred on Windows 7: $_" -Type Error
        $global:exitCode = 1
    } else {
        Write-LogMessage "An error occurred on non-Windows 7 system: $_" -Type Information
        $global:exitCode = 0
    }
}
finally {
    Write-LogMessage "Script completed with exit code: $global:exitCode" -Type Information
    exit $global:exitCode
}

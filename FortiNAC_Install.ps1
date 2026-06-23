param (
    [string]$MsiFilePath = (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) "FortiNAC Persistent Agent.msi")
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write output messages with color
function Write-ColorMessage {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-ColorMessage "Relaunching script as administrator..." "Yellow"
    Start-Process "powershell.exe" -ArgumentList "-File $($MyInvocation.MyCommand.Path)" -Verb RunAs
    exit
}

# Clear the console
Clear-Host

# Print current script path and MSI file path
Write-ColorMessage "Script is running from path: $($MyInvocation.MyCommand.Path)" "Cyan"
Write-ColorMessage "Using MSI file path: $MsiFilePath" "Cyan"

# Function to check if FortiNAC is already installed
function Test-FortiNACInstalled {
    $serviceName = "BNPagent"
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    return ($null -ne $service)
}

# Function to get correct registry path
function Get-RegistryPath {
    # Simplest approach - use architecture-specific registry path
    if ($env:PROCESSOR_ARCHITECTURE -eq "x86" -and $env:PROCESSOR_ARCHITEW6432 -eq $null) {
        # True 32-bit system
        $regPath = "HKLM:\SOFTWARE\Bradford Networks\Client Security Agent"
        Write-ColorMessage "Using 32-bit registry path" "Cyan"
    } else {
        # 64-bit system or 32-bit process on 64-bit system
        $regPath = "HKLM:\SOFTWARE\WOW6432Node\Bradford Networks\Client Security Agent"
        Write-ColorMessage "Using 64-bit registry path" "Cyan"
    }

    Write-ColorMessage "Selected registry path: $regPath" "Cyan"
    return $regPath
}

# Function to get registry values based on hostname
function Get-RegistryValuesByHostname {
    $hostname = $env:COMPUTERNAME
    Write-ColorMessage "Current hostname: $hostname" "Cyan"

    # Extract the Snif number from hostname using regex
    # This pattern looks for snif value anywhere in the hostname
    if ($hostname -match '(858|859|461)') {
        $snifNumber = $matches[1]
        Write-ColorMessage "Detected Snif number: $snifNumber" "Yellow"

        # Return special values for any Snif that need to be excluded
        $registryValues = @{
            "homeServer" = "fnc-cax1.corp.supersol.co.il"
            "allowedServers" = "fnc-cax1.corp.supersol.co.il,fnc-cax2.corp.supersol.co.il"
        }
        Write-ColorMessage "Using special registry values for Snif $snifNumber" "Green"
    } else {
        # Return default values for all other hostnames
        $registryValues = @{
            "homeServer" = "fnc-cax3.corp.supersol.co.il"
            "allowedServers" = "fnc-cax3.corp.supersol.co.il,fnc-cax4.corp.supersol.co.il,fnc-cax2.corp.supersol.co.il"
        }
        Write-ColorMessage "Using default registry values" "Green"
    }

    return $registryValues
}

# Function to check if registry values are correct
function Test-RegistryValues {
    param (
        [string]$RegPath
    )

    # Get the correct values based on hostname
    $correctValues = Get-RegistryValuesByHostname

    $result = $true

    # Check if registry path exists
    if (-not (Test-Path -Path $RegPath)) {
        Write-ColorMessage "Registry path does not exist: $RegPath" "Yellow"
        return $false
    }

    # Check each key
    foreach ($key in $correctValues.Keys) {
        try {
            $currentValue = Get-ItemProperty -Path $RegPath -Name $key -ErrorAction SilentlyContinue
            if ($null -eq $currentValue -or $currentValue.$key -ne $correctValues[$key]) {
                Write-ColorMessage "Registry value mismatch for $key" "Yellow"
                if ($null -eq $currentValue) {
                    Write-ColorMessage "  - Current: [Not Set]" "Yellow"
                } else {
                    Write-ColorMessage "  - Current: $($currentValue.$key)" "Yellow"
                }
                Write-ColorMessage "  - Expected: $($correctValues[$key])" "Yellow"
                $result = $false
            } else {
                Write-ColorMessage "Registry value correct for $key`: $($currentValue.$key)" "Green"
            }
        } catch {
            Write-ColorMessage "Error checking registry value $key`: $($_.Exception.Message)" "Red"
            $result = $false
        }
    }

    # Check if ServerIP exists and needs to be removed
    try {
        $serverIP = Get-ItemProperty -Path $RegPath -Name "ServerIP" -ErrorAction SilentlyContinue
        if ($null -ne $serverIP) {
            Write-ColorMessage "ServerIP registry value exists and should be removed" "Yellow"
            $result = $false
        }
    } catch {
        # This is fine, we don't want ServerIP to exist
    }

    return $result
}

# Function to update registry values
function Update-RegistryValues {
    param (
        [string]$RegPath
    )

    Write-ColorMessage "Updating registry values..." "Yellow"

    # Get the correct values based on hostname
    $correctValues = Get-RegistryValuesByHostname

    try {
        # Create registry path if it doesn't exist
        if (-not (Test-Path -Path $RegPath)) {
            Write-ColorMessage "Registry path does not exist. Creating it..." "Yellow"
            New-Item -Path $RegPath -Force | Out-Null
            Write-ColorMessage "Registry path created successfully." "Green"
        }

        # Set homeServer value
        Set-ItemProperty -Path $RegPath -Name "homeServer" -Value $correctValues["homeServer"] -Type String
        Write-ColorMessage "Set homeServer to: $($correctValues['homeServer'])" "Green"

        # Set allowedServers value
        Set-ItemProperty -Path $RegPath -Name "allowedServers" -Value $correctValues["allowedServers"] -Type String
        Write-ColorMessage "Set allowedServers to: $($correctValues['allowedServers'])" "Green"

        # Remove ServerIP value if it exists
        $serverIP = Get-ItemProperty -Path $RegPath -Name "ServerIP" -ErrorAction SilentlyContinue
        if ($null -ne $serverIP) {
            Remove-ItemProperty -Path $RegPath -Name "ServerIP"
            Write-ColorMessage "ServerIP registry value removed successfully." "Green"
        }

        Write-ColorMessage "Registry values updated successfully." "Green"
        return $true
    } catch {
        Write-ColorMessage "Error occurred while updating registry: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to set BNPagent service startup type to Automatic (Delayed Start)
function Set-FortiNACServiceDelayedStart {
    Write-ColorMessage "Setting BNPagent service startup type to Automatic (Delayed Start)..." "Yellow"
    try {
        $result = (Start-Process -FilePath "sc.exe" -ArgumentList "config BNPagent start= delayed-auto" -Wait -PassThru -NoNewWindow).ExitCode
        if ($result -eq 0) {
            Write-ColorMessage "BNPagent service startup type set to Automatic (Delayed Start) successfully." "Green"
            return $true
        } else {
            Write-ColorMessage "Failed to set BNPagent service startup type. sc.exe exit code: $result" "Red"
            return $false
        }
    } catch {
        Write-ColorMessage "Error setting BNPagent service startup type: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to restart the FortiNAC service
function Restart-FortiNACService {
    Write-ColorMessage "Restarting FortiNAC Persistent Agent Service..." "Yellow"
    try {
        $serviceName = "BNPagent"
        $processName = "BNPagent"

        # Kill the process directly instead of stopping service
        Write-ColorMessage "Killing FortiNAC process..." "Cyan"
        $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($processes) {
            foreach ($process in $processes) {
                Write-ColorMessage "Killing process ID: $($process.Id)" "Yellow"
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
            # Wait for process to terminate
            Start-Sleep -Seconds 3
        } else {
            Write-ColorMessage "No FortiNAC process found running." "Cyan"
        }

        # Start the service
        Write-ColorMessage "Starting service..." "Cyan"
        Start-Service -Name $serviceName -ErrorAction SilentlyContinue

        # Check if service is running
        Start-Sleep -Seconds 2
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq "Running") {
            Write-ColorMessage "Service started successfully." "Green"
            return $true
        } else {
            Write-ColorMessage "Warning: Could not confirm FortiNAC service is running." "Yellow"
            return $false
        }
    } catch {
        Write-ColorMessage "Error occurred while restarting service: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Main script logic
try {
    $isInstalled = Test-FortiNACInstalled
    $regPath = Get-RegistryPath

    if (-not $isInstalled) {
        Write-ColorMessage "FortiNAC is not installed. Will proceed with installation..." "Yellow"

        # Step 1: Import Certificate if script exists
        $certScriptPath = (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) "ImportCertificate.ps1")
        if (Test-Path -Path $certScriptPath) {
            Write-ColorMessage "Importing certificate..." "Yellow"
            try {
                & $certScriptPath
                Write-ColorMessage "Certificate import completed successfully." "Green"
            } catch {
                Write-ColorMessage "Error occurred during certificate import: $($_.Exception.Message)" "Red"
            }
        } else {
            Write-ColorMessage "Certificate import script not found. Continuing without importing certificate." "Yellow"
        }

        # Step 2: Install MSI file with /quiet parameter
        if (Test-Path -Path $MsiFilePath) {
            Write-ColorMessage "Starting MSI installation..." "Yellow"
            try {
                $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$MsiFilePath`" /quiet" -Wait -PassThru
                if ($process.ExitCode -ne 0) {
                    Write-ColorMessage "MSI installation exited with code: $($process.ExitCode)" "Yellow"
                } else {
                    Write-ColorMessage "MSI installation completed successfully." "Green"
                    # Set service startup type to Automatic (Delayed Start) after successful installation
                    Set-FortiNACServiceDelayedStart
                }
            } catch {
                Write-ColorMessage "Error occurred during MSI installation: $($_.Exception.Message)" "Red"
            }
        } else {
            Write-ColorMessage "Error: MSI file not found at `"$MsiFilePath`"." "Red"
        }
    } else {
        Write-ColorMessage "FortiNAC is already installed. Checking registry values..." "Yellow"
    }

    # Check if registry values are correct
    $valuesCorrect = Test-RegistryValues -RegPath $regPath

    if (-not $valuesCorrect) {
        Write-ColorMessage "Registry values need to be updated." "Yellow"
        Update-RegistryValues -RegPath $regPath
    } else {
        Write-ColorMessage "All registry values are correctly configured." "Green"
    }

    # Restart service if FortiNAC is now installed
    if (Test-FortiNACInstalled) {
        Restart-FortiNACService
    }

    # Restart Windows Installer service to prevent future MSI conflicts
    Write-ColorMessage "Restarting Windows Installer service to prevent MSI conflicts..." "Yellow"
    try {
        # Stop the Windows Installer service
        Write-ColorMessage "Stopping Windows Installer service (msiserver)..." "Cyan"
        Stop-Service -Name "msiserver" -Force -ErrorAction Stop

        # Wait a moment for the service to fully stop
        Start-Sleep -Seconds 2

        # Start the Windows Installer service
        Write-ColorMessage "Starting Windows Installer service (msiserver)..." "Cyan"
        Start-Service -Name "msiserver" -ErrorAction Stop

        Write-ColorMessage "Windows Installer service restarted successfully." "Green"
    } catch {
        Write-ColorMessage "Error restarting Windows Installer service: $($_.Exception.Message)" "Red"
        Write-ColorMessage "Trying alternative method using net commands..." "Yellow"

        try {
            # Alternative method using net commands with force switch
            $stopResult = (Start-Process -FilePath "net.exe" -ArgumentList "stop msiserver /y" -Wait -PassThru -NoNewWindow).ExitCode
            Start-Sleep -Seconds 2
            $startResult = (Start-Process -FilePath "net.exe" -ArgumentList "start msiserver" -Wait -PassThru -NoNewWindow).ExitCode

            if ($stopResult -eq 0 -and $startResult -eq 0) {
                Write-ColorMessage "Windows Installer service restarted successfully using net commands." "Green"
            } else {
                Write-ColorMessage "Failed to restart Windows Installer service using net commands." "Red"
                Write-ColorMessage "Warning: Future MSI installations may experience conflicts." "Yellow"
            }
        } catch {
            Write-ColorMessage "Error with alternative method: $($_.Exception.Message)" "Red"
            Write-ColorMessage "Warning: Future MSI installations may experience conflicts." "Yellow"
        }
    }

    Write-ColorMessage "Script execution completed successfully." "Green"
    Write-ColorMessage "Windows Installer service restart completed." "Cyan"
    exit 0
} catch {
    Write-ColorMessage "Script execution failed: $($_.Exception.Message)" "Red"
    exit 1
}

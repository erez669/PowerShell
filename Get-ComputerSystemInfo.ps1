# Local and Remote System Information v7
# Cross-platform (Windows 7 and above) with PowerShell v2+
# Shows details of currently running PC
# written by Erez Schwartz 28.10.24

function Get-DriveInfo {
    param ([string]$ComputerName)

    $drivesInfo = @()
    try {
        $logicalDisks = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ComputerName -Filter "DriveType = 3" # Only fixed drives

        foreach ($logicalDisk in $logicalDisks) {
            $diskDrive = Get-WmiObject -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$($logicalDisk.DeviceID)'} WHERE AssocClass = Win32_LogicalDiskToPartition" -ComputerName $ComputerName |
                ForEach-Object { Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($_.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition" -ComputerName $ComputerName }

            $driveType = "HDD" # Default type
            if ($diskDrive) {
                # Detect NVMe or SSD based on model and PNPDeviceID
                if ($diskDrive.PNPDeviceID -match 'NVMe' -or $diskDrive.Model -match 'NVMe') { $driveType = "NVMe" }
                elseif ($diskDrive.Model -match 'SSD|SOLID[\s-]STATE|MZ7|850|860|870|960|970|980') { $driveType = "SSD" }
                elseif ([string]::IsNullOrEmpty($diskDrive.PNPDeviceID) -and $diskDrive.Model -match 'SSD|SOLID[\s-]STATE|MZ7|850|860|870|960|970|980') {
                    $driveType = "SSD" # Fallback for Windows 7 if no PNPDeviceID is available
                }
            }

            # Clean model name and store details
            $cleanedModel = $diskDrive.Model -replace "\s*SCSI Disk Device$|ATA\s*", ""
            $cleanedModel = $cleanedModel -replace "^ADAT\s", "ADATA "
            $cleanedModel = $cleanedModel -replace "\s+", " " # Remove extra spaces
            
            # Store drive information
            $drivesInfo += [pscustomobject]@{
                DriveLetter   = $logicalDisk.DeviceID
                CapacityGB    = [math]::Round($logicalDisk.Size / 1GB, 2)
                FreeSpaceGB   = [math]::Round($logicalDisk.FreeSpace / 1GB, 2)
                FreeSpacePct  = [math]::Round(($logicalDisk.FreeSpace / $logicalDisk.Size) * 100, 2)
                DriveType     = $driveType
                Model         = $cleanedModel
            }
        }
    }
    catch {
        Write-Host "Error retrieving drive information for $ComputerName : $_" -ForegroundColor Red
    }

    return $drivesInfo
}

function Get-WindowsVersionInfo {
    param([string]$ComputerName)

    try {
        if ($ComputerName -eq "localhost" -or $ComputerName -eq $env:COMPUTERNAME) {
            $os = Get-WmiObject -Class Win32_OperatingSystem
            $regInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $buildNumber = if ($regInfo.CurrentBuild -and $regInfo.UBR) { "$($regInfo.CurrentBuild).$($regInfo.UBR)" } else { $regInfo.CurrentBuild }
            
            # Retrieve either DisplayVersion or ReleaseId
            $featureUpdate = if ($regInfo.DisplayVersion) { $regInfo.DisplayVersion } elseif ($regInfo.ReleaseId) { $regInfo.ReleaseId } else { "Not Available" }
        } 
        else {
            $buildNumber = $featureUpdate = "Unknown"
            try {
                $buildInfo = Invoke-Command -ComputerName $ComputerName -ScriptBlock { 
                    Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" | 
                    Select-Object -Property CurrentBuild, UBR, DisplayVersion, ReleaseId
                }
                $buildNumber = if ($buildInfo.CurrentBuild -and $buildInfo.UBR) { "$($buildInfo.CurrentBuild).$($buildInfo.UBR)" } else { $buildInfo.CurrentBuild }
                
                # Retrieve either DisplayVersion or ReleaseId
                $featureUpdate = if ($buildInfo.DisplayVersion) { $buildInfo.DisplayVersion } elseif ($buildInfo.ReleaseId) { $buildInfo.ReleaseId } else { "Not Available" }
            }
            catch {
                Write-Host "Error retrieving build information for $ComputerName : $_" -ForegroundColor Red
            }
        }

        return @{
            "Version" = $os.Version
            "Build" = $buildNumber
            "FeatureUpdate" = $featureUpdate
        }
    }
    catch {
        Write-Host "Error retrieving Windows version info for $ComputerName : $_" -ForegroundColor Red
        return @{
            "Version" = "Unknown"
            "Build" = "Unknown"
            "FeatureUpdate" = "Unknown"
        }
    }
}

function Get-SystemInformation {
    param([string]$ComputerName)

    $ErrorActionPreference = 'SilentlyContinue'

    try {
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName
        $computerBIOS = Get-WmiObject -Class Win32_BIOS -ComputerName $ComputerName
        $computerOS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName
        $computerCPU = Get-WmiObject -Class Win32_Processor -ComputerName $ComputerName | Select-Object -First 1
        $windowsInfo = Get-WindowsVersionInfo -ComputerName $ComputerName

        # Retrieve all drives information
        $drivesInfo = Get-DriveInfo -ComputerName $ComputerName

        Clear-Host
        Write-Host "System Information for: $ComputerName" -ForegroundColor Green
        Write-Host "---------------------------------------" -ForegroundColor Green
        Write-Host "Manufacturer: $($computerSystem.Manufacturer)"
        Write-Host "Model: $($computerSystem.Model)"
        Write-Host "Serial Number: $($computerBIOS.SerialNumber)"
        Write-Host "CPU: $($computerCPU.Name)"
        
        # Display each drive's information
        foreach ($drive in $drivesInfo) {
            Write-Host "`nDrive Letter: $($drive.DriveLetter)" -ForegroundColor Cyan
            Write-Host "  Capacity: $($drive.CapacityGB) GB"
            Write-Host "  Free Space: $($drive.FreeSpaceGB) GB ($($drive.FreeSpacePct)%)"
            Write-Host "  Type: $($drive.DriveType)"
            Write-Host "  Model: $($drive.Model)"
        }

        Write-Host "`nRAM: $([math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)) GB"
        Write-Host "Operating System: $($computerOS.Caption)"
        Write-Host "Windows Build: $($windowsInfo.Build)"
        Write-Host "Feature Update: $($windowsInfo.FeatureUpdate)"

        Write-Host "`nInstallation Information:" -ForegroundColor Green
        Write-Host "---------------------------------------" -ForegroundColor Green
        $installDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($computerOS.InstallDate)
        Write-Host "Original Install Date: $($installDate.ToString("dd/MM/yyyy HH:mm:ss"))"

        Write-Host "`nUser Information:" -ForegroundColor Green
        Write-Host "---------------------------------------" -ForegroundColor Green
        $loggedOnUser = if ($ComputerName -eq "localhost" -or $ComputerName -eq $env:COMPUTERNAME) {
            "$env:USERDOMAIN\$env:USERNAME"
        } else {
            $computerSystem.UserName
        }
        
        Write-Host "Current User: $loggedOnUser"
        $lastBootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($computerOS.LastBootUpTime)
        Write-Host "Last Reboot: $($lastBootTime.ToString("dd/MM/yyyy HH:mm:ss"))"
    }
    catch {
        Write-Host "Error retrieving information from $ComputerName : $_" -ForegroundColor Red
    }
}

# Main loop
while ($true) {
    Write-Host "`nGet Computer Hardware Information" -ForegroundColor Cyan
    Write-Host "---------------------------------------"
    $computerName = Read-Host "Enter Computername or IP Address"
    
    if ($computerName) {
        Get-SystemInformation -ComputerName $computerName
    }
    
    Write-Host "`nPress Enter to check another computer or Ctrl+C to exit..."
    Read-Host
}

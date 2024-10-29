# Local and Remote System Information v8
# Cross-platform (Windows 7 and above) with PowerShell v2+ compatibility
# Shows details of currently running PC
# Written by Erez Schwartz 28.10.24

function Get-PowerShellVersion {
    return $PSVersionTable.PSVersion.Major
}

function Get-OSVersion {
    param ([string]$ComputerName)
    
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName
        $osVersion = [Version]$os.Version
        return [PSCustomObject]@{
            Major = $osVersion.Major
            Minor = $osVersion.Minor
            Build = $osVersion.Build
            IsWindows7OrLower = ($osVersion.Major -lt 6) -or ($osVersion.Major -eq 6 -and $osVersion.Minor -le 1)
        }
    }
    catch {
        Write-Host "Error detecting OS version for $ComputerName : $_" -ForegroundColor Red
        return $null
    }
}

function Get-WindowsVersionInfo {
    param([string]$ComputerName)

    try {
        if ($ComputerName -eq "localhost" -or $ComputerName -eq $env:COMPUTERNAME) {
            $os = Get-WmiObject -Class Win32_OperatingSystem
            $regInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $buildNumber = if ($regInfo.CurrentBuild -and $regInfo.UBR) { "$($regInfo.CurrentBuild).$($regInfo.UBR)" } else { $regInfo.CurrentBuild }
            
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

function Get-LegacyDriveInfo {
    param ([string]$ComputerName)
    
    $drivesInfo = @()
    try {
        $logicalDisks = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ComputerName -Filter "DriveType = 3"
        
        foreach ($logicalDisk in $logicalDisks) {
            $diskDrive = Get-WmiObject -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$($logicalDisk.DeviceID)'} WHERE AssocClass = Win32_LogicalDiskToPartition" -ComputerName $ComputerName |
                ForEach-Object { 
                    Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($_.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition" -ComputerName $ComputerName 
                }
            
            if ($diskDrive) {
                # Get storage controller info
                $storageProps = Get-WmiObject -Class Win32_DiskDrive -ComputerName $ComputerName |
                    Where-Object { $_.DeviceID -eq $diskDrive.DeviceID }
                
                # Get PNP device info for better interface detection
                if ($storageProps) {
                    $pnpEntity = Get-WmiObject -Class Win32_PnPEntity -ComputerName $ComputerName |
                        Where-Object { $_.PNPDeviceID -eq $storageProps.PNPDeviceID }
                }
                
                # Model name handling
                $model = $diskDrive.Model.Trim()
                
                # Check if model ends with "SCSI Disk Device"
                $hasSCSISuffix = $model -match "SCSI Disk Device$"
                
                # Remove suffix temporarily if present
                if ($hasSCSISuffix) {
                    $model = $model -replace "SCSI Disk Device$", ""
                    $model = $model.Trim()
                }
                
                # Fix ADATA model names
                if ($model -match "^ADAT\s*SP") {
                    $model = $model -replace "^ADAT\s*SP", "ADATA SP"
                }
                
                # Clean up any multiple spaces
                $model = $model -replace "\s+", " "
                $model = $model.Trim()
                
                # Add back SCSI suffix if it was present
                if ($hasSCSISuffix) {
                    $model = "$model SCSI Disk Device"
                }
                
                # Determine drive type based on controller and interface
                $driveType = "HDD" # Default type
                try {
                    if ($storageProps) {
                        if ($pnpEntity.PNPClass -eq "NVME" -or 
                            $storageProps.InterfaceType -eq "NVME" -or
                            $pnpEntity.Name -match "NVM Express") {
                            $driveType = "NVMe"
                        }
                        elseif ($storageProps.InterfaceType -eq "SCSI" -or $storageProps.InterfaceType -eq "IDE") {
                            # Get performance metrics
                            $diskPerf = Get-WmiObject -Class Win32_DiskPerformance -ComputerName $ComputerName |
                                Where-Object { $_.Name -eq $diskDrive.DeviceID }
                            
                            # Check for SSD characteristics
                            if (($diskPerf -and $diskPerf.AvgDiskSecPerTransfer -lt 0.015) -or  # Fast access time
                                $storageProps.MediaType -match "SSD" -or                         # Explicitly marked as SSD
                                $storageProps.Capabilities -contains 4) {                        # SSD capability flag
                                $driveType = "SSD"
                            }
                        }
                    }
                }
                catch {
                    Write-Verbose "Error detecting drive type through WMI: $_"
                }
                
                $drivesInfo += [PSCustomObject]@{
                    DriveLetter   = $logicalDisk.DeviceID
                    CapacityGB    = [math]::Round($logicalDisk.Size / 1GB, 2)
                    FreeSpaceGB   = [math]::Round($logicalDisk.FreeSpace / 1GB, 2)
                    FreeSpacePct  = [math]::Round(($logicalDisk.FreeSpace / $logicalDisk.Size) * 100, 2)
                    DriveType     = $driveType
                    Model         = $model
                    SerialNumber  = $diskDrive.SerialNumber.Trim()
                }
            }
        }
    }
    catch {
        Write-Host "Error retrieving legacy drive information for $ComputerName : $_" -ForegroundColor Red
    }
    
    return $drivesInfo
}

function Get-ModernDriveInfo {
    param ([string]$ComputerName)
    
    $drivesInfo = @()
    try {
        $physicalDisks = Get-CimInstance -ClassName MSFT_PhysicalDisk -Namespace root\Microsoft\Windows\Storage -ComputerName $ComputerName
        $logicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $ComputerName -Filter "DriveType = 3"
        $partitionToDisk = Get-CimInstance -ClassName MSFT_Partition -Namespace root\Microsoft\Windows\Storage -ComputerName $ComputerName
        
        foreach ($logicalDisk in $logicalDisks) {
            $partition = $partitionToDisk | Where-Object { $_.DriveLetter -eq $logicalDisk.DeviceID[0] }
            if ($partition) {
                $physicalDisk = $physicalDisks | Where-Object { $_.DeviceId -eq $partition.DiskNumber }
                
                if ($physicalDisk) {
                    # Get the exact model name
                    $model = $physicalDisk.Model.Trim()
                    
                    # Determine drive type based on bus type and media type
                    $driveType = switch ($physicalDisk.BusType) {
                        17 { "NVMe" }  # NVMe bus type
                        default {
                            switch ($physicalDisk.MediaType) {
                                3 { "HDD" }  # Rotational disk
                                4 { "SSD" }  # Solid state disk
                                default {
                                    # Fallback checks
                                    if ($physicalDisk.SpindleSpeed -eq 0) { 
                                        "SSD"
                                    }
                                    else { 
                                        "HDD"
                                    }
                                }
                            }
                        }
                    }
                    
                    $drivesInfo += [PSCustomObject]@{
                        DriveLetter   = $logicalDisk.DeviceID
                        CapacityGB    = [math]::Round($logicalDisk.Size / 1GB, 2)
                        FreeSpaceGB   = [math]::Round($logicalDisk.FreeSpace / 1GB, 2)
                        FreeSpacePct  = [math]::Round(($logicalDisk.FreeSpace / $logicalDisk.Size) * 100, 2)
                        DriveType     = $driveType
                        Model         = $model
                        SerialNumber  = $physicalDisk.SerialNumber.Trim()
                    }
                }
            }
        }
    }
    catch {
        Write-Host "Error retrieving modern drive information for $ComputerName : $_" -ForegroundColor Red
    }
    
    return $drivesInfo
}

function Get-DriveInfo {
    param ([string]$ComputerName)
    
    $osVersion = Get-OSVersion -ComputerName $ComputerName
    $psVersion = Get-PowerShellVersion
    
    if ($null -eq $osVersion) {
        return @()
    }
    
    if ($osVersion.IsWindows7OrLower -or $psVersion -lt 3) {
        Write-Verbose "Using legacy drive detection method for Windows 7 or PowerShell v2"
        return Get-LegacyDriveInfo -ComputerName $ComputerName
    }
    else {
        Write-Verbose "Using modern drive detection method"
        return Get-ModernDriveInfo -ComputerName $ComputerName
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
        
        $drivesInfo = Get-DriveInfo -ComputerName $ComputerName
        
        Clear-Host
        Write-Host "System Information for: $ComputerName" -ForegroundColor Green
        Write-Host "---------------------------------------" -ForegroundColor Green
        Write-Host "Manufacturer: $($computerSystem.Manufacturer)"
        Write-Host "Model: $($computerSystem.Model)"
        Write-Host "Serial Number: $($computerBIOS.SerialNumber)"
        Write-Host "CPU: $($computerCPU.Name)"
        
        foreach ($drive in $drivesInfo) {
            Write-Host "`nDrive Letter: $($drive.DriveLetter)" -ForegroundColor Cyan
            Write-Host "  Capacity: $($drive.CapacityGB) GB"
            Write-Host "  Free Space: $($drive.FreeSpaceGB) GB ($($drive.FreeSpacePct)%)"
            Write-Host "  Type: $($drive.DriveType)"
            Write-Host "  Model: $($drive.Model)"
            if ($drive.SerialNumber) {
                Write-Host "  Serial Number: $($drive.SerialNumber)"
            }
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
        Get-SystemInformation -ComputerName $ComputerName
    }
    
    Write-Host "`nPress Enter to check another computer or Ctrl+C to exit..."
    Read-Host
}

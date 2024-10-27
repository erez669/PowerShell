# Local and Remote System Information v5
# Cross-platform (Windows 7 and above) with PowerShell v2/v5+ compatibility
# Use CIM on modern systems and WMI for legacy systems
# Shows details of currently running PC
# written by Erez Schwartz 27.10.24

function Get-DriveType {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter
    )

    try {
        $logicalDisk = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ComputerName -Filter "DeviceID='$($DriveLetter):'"
        if (-not $logicalDisk) { return "HDD" }

        $partition = Get-WmiObject -ComputerName $ComputerName -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$($logicalDisk.DeviceID)'} WHERE AssocClass = Win32_LogicalDiskToPartition"
        if (-not $partition) { return "HDD" }

        $diskDrive = Get-WmiObject -ComputerName $ComputerName -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition"
        if (-not $diskDrive) { return "HDD" }

        if ($diskDrive.PNPDeviceID -match 'NVMe') { return "NVMe" }
        if ($diskDrive.Model -match 'NVMe') { return "NVMe" }

        $modelUpper = $diskDrive.Model.ToUpper()
        if ($modelUpper -match 'SSD|SOLID[\s-]STATE|NVME|PM\d{3}|SM\d{3}|MZ7|850|860|870|960|970|980') {
            if ($modelUpper -match 'NVME') { return "NVMe" }
            return "SSD"
        }

        if ($diskDrive.InterfaceType -eq "SCSI" -and $diskDrive.Model -match "(SSD|NVMe)") {
            if ($diskDrive.Model -match "NVMe") { return "NVMe" }
            return "SSD"
        }

        try {
            $msftDisk = Get-WmiObject -Namespace "root\Microsoft\Windows\Storage" -Class "MSFT_PhysicalDisk" -ComputerName $ComputerName -ErrorAction Stop |
                Where-Object { $_.DeviceId -eq $diskDrive.Index }
            
            if ($msftDisk) {
                switch ($msftDisk.MediaType) {
                    3 { return "HDD" }    # HDD
                    4 { return "SSD" }    # SSD
                    5 { return "SCM" }    # SCM (Storage Class Memory)
                }
            }
        } catch {}
        return "HDD"
    }
    catch {
        return "HDD"
    }
}

function Get-WindowsVersionInfo {
    param([string]$ComputerName)

    $osVersion = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName).Version
    $majorVersion = [int]$osVersion.Split('.')[0]

    if ($majorVersion -lt 10) {
        $windowsOS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName
        return @{
            "Version" = $windowsOS.Version
            "Build" = $windowsOS.BuildNumber
            "FeatureUpdate" = "Not Available (Windows 7 or older)"
        }
    } else {
        try {
            $cimOS = Get-WmiObject -ClassName Win32_OperatingSystem -ComputerName $ComputerName
            $regPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $regInfo = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                $key = Get-ItemProperty -Path "HKLM:\$using:regPath"
                return @{
                    DisplayVersion = $key.DisplayVersion
                    ReleaseId = $key.ReleaseId
                    CurrentBuild = $key.CurrentBuild
                    UBR = $key.UBR
                }
            }

            $buildNumber = if ($regInfo.CurrentBuild -and $regInfo.UBR) { "$($regInfo.CurrentBuild).$($regInfo.UBR)" } else { "Unknown" }
            $featureUpdate = if ($regInfo.DisplayVersion) { 
                $regInfo.DisplayVersion 
            } elseif ($regInfo.ReleaseId) { 
                $regInfo.ReleaseId 
            } else { 
                "Not Available" 
            }

            return @{
                "Version" = $cimOS.Version
                "Build" = $buildNumber
                "FeatureUpdate" = $featureUpdate
            }
        } catch {
            Write-Host "Error accessing registry or retrieving system info from $ComputerName : $_" -ForegroundColor Red
            return @{
                "Version" = "Unknown"
                "Build" = "Unknown"
                "FeatureUpdate" = "Unknown"
            }
        }
    }
}

function Get-SystemInformation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )

    $ErrorActionPreference = 'SilentlyContinue'
    
    try {
        # Gather system information
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName
        $computerBIOS = Get-WmiObject -Class Win32_BIOS -ComputerName $ComputerName
        $computerOS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName
        $computerCPU = Get-WmiObject -Class Win32_Processor -ComputerName $ComputerName
        $computerHDD = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ComputerName -Filter "DeviceID = 'C:'"

        # Get Windows Version Information based on OS
        $windowsInfo = Get-WindowsVersionInfo -ComputerName $ComputerName

        # Get drive type
        $driveType = Get-DriveType -ComputerName $ComputerName -DriveLetter "C"
        
        # Clear screen and format output
        Clear-Host
        
        # System Information Section
        Write-Host "System Information for: $($computerSystem.Name)"
        Write-Host "---------------------------------------"
        Write-Host "Manufacturer: $($computerSystem.Manufacturer)"
        Write-Host "Model: $($computerSystem.Model)"
        Write-Host "Serial Number: $($computerBIOS.SerialNumber)"
        Write-Host "CPU: $($computerCPU.Name)"
        
        if ($computerHDD) {
            $hddCapacity = [math]::Round($computerHDD.Size/1GB, 2)
            $hddFreeSpace = [math]::Round($computerHDD.FreeSpace/1GB, 2)
            $hddFreePercent = [math]::Round(($computerHDD.FreeSpace/$computerHDD.Size) * 100, 2)
            
            Write-Host "HDD Capacity: $hddCapacity GB"
            Write-Host "HDD Type: $driveType"
            Write-Host "HDD Free Space: $hddFreeSpace GB ($hddFreePercent%)"
        }
        
        $ramGB = [math]::Round($computerSystem.TotalPhysicalMemory/1GB, 2)
        Write-Host "RAM: $ramGB GB"
        Write-Host "Operating System: $($computerOS.Caption)"
        Write-Host "Windows Build: $($windowsInfo.Build) (Version $($windowsInfo.Version))"
        Write-Host "Feature Update: $($windowsInfo.FeatureUpdate)"
        
        # Installation Information Section
        Write-Host "`n"
        Write-Host "Installation Information:"
        Write-Host "---------------------------------------"
        $installDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($computerOS.InstallDate)
        Write-Host "Original Install Date: $($installDate.ToString("MM/dd/yyyy HH:mm:ss"))"
        
        # User Information Section
        Write-Host "`n"
        Write-Host "User Information:"
        Write-Host "---------------------------------------"
        Write-Host "Current User: $($computerSystem.UserName)"
        
        $lastBootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($computerOS.LastBootUpTime)
        Write-Host "Last Reboot: $($lastBootTime.ToString("MM/dd/yyyy HH:mm:ss"))"
        
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

# Local and Remote System Information v7
# Cross-platform (Windows 7 and above) with PowerShell v2+
# Shows details of currently running PC
# written by Erez Schwartz 28.10.24

function Get-DriveType {
    param (
        [string]$ComputerName,
        [string]$DriveLetter
    )

    try {
        $logicalDisk = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ComputerName -Filter "DeviceID='$($DriveLetter):'"
        if (-not $logicalDisk) { return "HDD" }

        $diskDrive = Get-WmiObject -ComputerName $ComputerName -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$($logicalDisk.DeviceID)'} WHERE AssocClass = Win32_LogicalDiskToPartition" |
            ForEach-Object { Get-WmiObject -ComputerName $ComputerName -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($_.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition" }

        if (-not $diskDrive) { return "HDD" }

        if ($diskDrive.PNPDeviceID -match 'NVMe' -or $diskDrive.Model -match 'NVMe') { return "NVMe" }
        if ($diskDrive.Model.ToUpper() -match 'SSD|SOLID[\s-]STATE|NVME|PM\d{3}|SM\d{3}|MZ7|850|860|870|960|970|980') {
            return "SSD"
        }

        return "HDD"
    }
    catch {
        return "HDD"
    }
}

function Get-WindowsVersionInfo {
    param([string]$ComputerName)

    try {
        # Local machine retrieval
        if ($ComputerName -eq "localhost" -or $ComputerName -eq $env:COMPUTERNAME) {
            $os = Get-WmiObject -Class Win32_OperatingSystem
            $regInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $buildNumber = if ($regInfo.CurrentBuild -and $regInfo.UBR) { "$($regInfo.CurrentBuild).$($regInfo.UBR)" } else { $regInfo.CurrentBuild }
            $featureUpdate = if ($regInfo.DisplayVersion) { $regInfo.DisplayVersion } elseif ($regInfo.ReleaseId) { $regInfo.ReleaseId } else { "Not Available" }
        } 
        else {
            # Remote retrieval with Invoke-Command
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
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

        # Interpret feature update into readable version
        if ($featureUpdate -match '^\d{4}$') {
            # Convert numeric ReleaseId, e.g., "2004" to "20H1"
            $featureUpdate = if ([int]$featureUpdate -ge 1909) { $featureUpdate.Insert(2, "H") } else { $featureUpdate }
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
        $computerHDD = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ComputerName -Filter "DeviceID = 'C:'"
        
        $windowsInfo = Get-WindowsVersionInfo -ComputerName $ComputerName
        $driveType = Get-DriveType -ComputerName $ComputerName -DriveLetter "C"

        Clear-Host
        Write-Host "System Information for: $ComputerName" -ForegroundColor Green
        Write-Host "---------------------------------------" -ForegroundColor Green
        Write-Host "Manufacturer: $($computerSystem.Manufacturer)"
        Write-Host "Model: $($computerSystem.Model)"
        Write-Host "Serial Number: $($computerBIOS.SerialNumber)"
        Write-Host "CPU: $($computerCPU.Name)"

        if ($computerHDD) {
            Write-Host "HDD Capacity: $([math]::Round($computerHDD.Size / 1GB, 2)) GB"
            Write-Host "HDD Type: $driveType"
            Write-Host "HDD Free Space: $([math]::Round($computerHDD.FreeSpace / 1GB, 2)) GB ($([math]::Round(($computerHDD.FreeSpace / $computerHDD.Size) * 100, 2))%)"
        }

        Write-Host "RAM: $([math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)) GB"
        Write-Host "Operating System: $($computerOS.Caption)"
        Write-Host "Windows Build: $($windowsInfo.Build) (Version $($windowsInfo.Version))"
        Write-Host "Feature Update: $($windowsInfo.FeatureUpdate)"

        Write-Host "`nInstallation Information:" -ForegroundColor Green
        Write-Host "---------------------------------------" -ForegroundColor Green
        $installDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($computerOS.InstallDate)
        Write-Host "Original Install Date: $($installDate.ToString("dd/MM/yyyy HH:mm:ss"))"

        Write-Host "`nUser Information:" -ForegroundColor Green
        Write-Host "---------------------------------------" -ForegroundColor Green
        Write-Host "Current User: $($computerSystem.UserName)"
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

# Local and Remote System Information v10
# Cross-platform (Windows 7 and above) with PowerShell v2+ compatibility
# Shows details of currently running PC
# Written by Erez Schwartz 28.10.24
# v9:  Added friendly device model resolution (vendor-aware: Lenovo/Dell/HP/Toshiba/ASUS)
# v10: Fixed PS v2 compatibility - replaced [PSCustomObject] with New-Object PSObject + Add-Member
#      [PSCustomObject] is PS v3+ only; Get-LegacyDriveInfo is called on PS v2 so must be fixed.
#      Get-ModernDriveInfo (Get-CimInstance path) is never called on PS v2 due to routing logic,
#      but was also updated for consistency.

function Get-PowerShellVersion {
    return $PSVersionTable.PSVersion.Major
}

function Get-OSVersion {
    param ([string]$ComputerName)
    
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName
        $osVersion = [Version]$os.Version
        
        $result = New-Object PSObject
        Add-Member -InputObject $result -MemberType NoteProperty -Name Major            -Value $osVersion.Major
        Add-Member -InputObject $result -MemberType NoteProperty -Name Minor            -Value $osVersion.Minor
        Add-Member -InputObject $result -MemberType NoteProperty -Name Build            -Value $osVersion.Build
        Add-Member -InputObject $result -MemberType NoteProperty -Name IsWindows7OrLower -Value (($osVersion.Major -lt 6) -or ($osVersion.Major -eq 6 -and $osVersion.Minor -le 1))
        return $result
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
            "Version"       = $os.Version
            "Build"         = $buildNumber
            "FeatureUpdate" = $featureUpdate
        }
    }
    catch {
        Write-Host "Error retrieving Windows version info for $ComputerName : $_" -ForegroundColor Red
        return @{
            "Version"       = "Unknown"
            "Build"         = "Unknown"
            "FeatureUpdate" = "Unknown"
        }
    }
}

# ---------------------------------------------------------------------------
# Resolve a human-readable device model name, vendor-aware
# PS v2 compatible
# ---------------------------------------------------------------------------
function Get-FriendlyModelName {
    param(
        [string]$ComputerName,
        [string]$Manufacturer,   # already normalised to uppercase
        [string]$RawModel        # Win32_ComputerSystem.Model (may be a code like 10NK003KIV)
    )

    $friendly = $null

    # --- Lenovo: Win32_ComputerSystemProduct.Version holds the real name ---
    if ($Manufacturer -match "LENOVO") {
        try {
            $csp = Get-WmiObject -Class Win32_ComputerSystemProduct -ComputerName $ComputerName -ErrorAction Stop
            if ($csp.Version -and $csp.Version.Trim() -ne "" -and $csp.Version.Trim() -ne "None") {
                $friendly = $csp.Version.Trim()
            }
        }
        catch { }

        # Fallback: BaseBoard may carry the name on some ThinkCentre / ThinkStation units
        if (-not $friendly) {
            try {
                $bb = Get-WmiObject -Class Win32_BaseBoard -ComputerName $ComputerName -ErrorAction Stop
                if ($bb.Product -and $bb.Product.Trim() -ne "") {
                    $friendly = $bb.Product.Trim()
                }
            }
            catch { }
        }
    }

    # --- Dell / HP / Toshiba / ASUS: Win32_ComputerSystem.Model is already friendly ---
    # Nothing extra needed; the raw model is already human-readable.

    # If we still have nothing, use the raw model as-is
    if (-not $friendly) {
        $friendly = $RawModel
    }

    # Clean duplicate manufacturer prefix that some vendors embed in the model string
    # e.g. "HP HP ProDesk 600" → "HP ProDesk 600"
    $cleanManufacturer = ($Manufacturer -replace "Inc\.|Corp\.|Co\.|Ltd\.|,", "").Trim()
    $words = $cleanManufacturer -split "\s+"
    foreach ($word in $words) {
        if ($word.Length -gt 2 -and $friendly -imatch "^\s*$([regex]::Escape($word))\s+") {
            $friendly = ($friendly -ireplace "^\s*$([regex]::Escape($word))\s+", "").Trim()
        }
    }

    return $friendly
}

# ---------------------------------------------------------------------------
# New-DriveObject helper - PS v2 compatible replacement for [PSCustomObject]
# ---------------------------------------------------------------------------
function New-DriveObject {
    param(
        [string]$DriveLetter,
        [double]$CapacityGB,
        [double]$FreeSpaceGB,
        [double]$FreeSpacePct,
        [string]$DriveType,
        [string]$Model,
        [string]$SerialNumber
    )

    $obj = New-Object PSObject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name DriveLetter  -Value $DriveLetter
    Add-Member -InputObject $obj -MemberType NoteProperty -Name CapacityGB   -Value $CapacityGB
    Add-Member -InputObject $obj -MemberType NoteProperty -Name FreeSpaceGB  -Value $FreeSpaceGB
    Add-Member -InputObject $obj -MemberType NoteProperty -Name FreeSpacePct -Value $FreeSpacePct
    Add-Member -InputObject $obj -MemberType NoteProperty -Name DriveType    -Value $DriveType
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Model        -Value $Model
    Add-Member -InputObject $obj -MemberType NoteProperty -Name SerialNumber -Value $SerialNumber
    return $obj
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
                $storageProps = Get-WmiObject -Class Win32_DiskDrive -ComputerName $ComputerName |
                    Where-Object { $_.DeviceID -eq $diskDrive.DeviceID }
                
                if ($storageProps) {
                    $pnpEntity = Get-WmiObject -Class Win32_PnPEntity -ComputerName $ComputerName |
                        Where-Object { $_.PNPDeviceID -eq $storageProps.PNPDeviceID }
                }
                
                $model = $diskDrive.Model.Trim()
                $hasSCSISuffix = $model -match "SCSI Disk Device$"
                if ($hasSCSISuffix) { $model = ($model -replace "SCSI Disk Device$", "").Trim() }
                if ($model -match "^ADAT\s*SP") { $model = $model -replace "^ADAT\s*SP", "ADATA SP" }
                $model = ($model -replace "\s+", " ").Trim()
                if ($hasSCSISuffix) { $model = "$model SCSI Disk Device" }
                
                $driveType = "HDD"
                try {
                    if ($storageProps) {
                        if ($pnpEntity.PNPClass -eq "NVME" -or 
                            $storageProps.InterfaceType -eq "NVME" -or
                            $pnpEntity.Name -match "NVM Express") {
                            $driveType = "NVMe"
                        }
                        elseif ($storageProps.InterfaceType -eq "SCSI" -or $storageProps.InterfaceType -eq "IDE") {
                            $diskPerf = Get-WmiObject -Class Win32_DiskPerformance -ComputerName $ComputerName |
                                Where-Object { $_.Name -eq $diskDrive.DeviceID }
                            if (($diskPerf -and $diskPerf.AvgDiskSecPerTransfer -lt 0.015) -or
                                $storageProps.MediaType -match "SSD" -or
                                $storageProps.Capabilities -contains 4) {
                                $driveType = "SSD"
                            }
                        }
                    }
                }
                catch { Write-Verbose "Error detecting drive type through WMI: $_" }
                
                $drivesInfo += New-DriveObject `
                    -DriveLetter  $logicalDisk.DeviceID `
                    -CapacityGB   ([math]::Round($logicalDisk.Size / 1GB, 2)) `
                    -FreeSpaceGB  ([math]::Round($logicalDisk.FreeSpace / 1GB, 2)) `
                    -FreeSpacePct ([math]::Round(($logicalDisk.FreeSpace / $logicalDisk.Size) * 100, 2)) `
                    -DriveType    $driveType `
                    -Model        $model `
                    -SerialNumber $diskDrive.SerialNumber.Trim()
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
        $physicalDisks   = Get-CimInstance -ClassName MSFT_PhysicalDisk -Namespace root\Microsoft\Windows\Storage -ComputerName $ComputerName
        $logicalDisks    = Get-CimInstance -ClassName Win32_LogicalDisk  -ComputerName $ComputerName -Filter "DriveType = 3"
        $partitionToDisk = Get-CimInstance -ClassName MSFT_Partition      -Namespace root\Microsoft\Windows\Storage -ComputerName $ComputerName
        
        foreach ($logicalDisk in $logicalDisks) {
            $partition = $partitionToDisk | Where-Object { $_.DriveLetter -eq $logicalDisk.DeviceID[0] }
            if ($partition) {
                $physicalDisk = $physicalDisks | Where-Object { $_.DeviceId -eq $partition.DiskNumber }
                
                if ($physicalDisk) {
                    $model = $physicalDisk.Model.Trim()
                    
                    $driveType = switch ($physicalDisk.BusType) {
                        17 { "NVMe" }
                        default {
                            switch ($physicalDisk.MediaType) {
                                3 { "HDD" }
                                4 { "SSD" }
                                default { if ($physicalDisk.SpindleSpeed -eq 0) { "SSD" } else { "HDD" } }
                            }
                        }
                    }
                    
                    $drivesInfo += New-DriveObject `
                        -DriveLetter  $logicalDisk.DeviceID `
                        -CapacityGB   ([math]::Round($logicalDisk.Size / 1GB, 2)) `
                        -FreeSpaceGB  ([math]::Round($logicalDisk.FreeSpace / 1GB, 2)) `
                        -FreeSpacePct ([math]::Round(($logicalDisk.FreeSpace / $logicalDisk.Size) * 100, 2)) `
                        -DriveType    $driveType `
                        -Model        $model `
                        -SerialNumber $physicalDisk.SerialNumber.Trim()
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
    
    if ($null -eq $osVersion) { return @() }
    
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
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem      -ComputerName $ComputerName
        $computerBIOS   = Get-WmiObject -Class Win32_BIOS                -ComputerName $ComputerName
        $computerOS     = Get-WmiObject -Class Win32_OperatingSystem     -ComputerName $ComputerName
        $computerCPU    = Get-WmiObject -Class Win32_Processor           -ComputerName $ComputerName | Select-Object -First 1
        $windowsInfo    = Get-WindowsVersionInfo -ComputerName $ComputerName
        $drivesInfo     = Get-DriveInfo          -ComputerName $ComputerName

        # ── Friendly model resolution ──────────────────────────────────────
        $rawManufacturer = $computerSystem.Manufacturer.Trim()
        $rawModel        = $computerSystem.Model.Trim()
        $friendlyModel   = Get-FriendlyModelName -ComputerName $ComputerName `
                                                  -Manufacturer $rawManufacturer `
                                                  -RawModel     $rawModel

        # Show both when the friendly name differs from the raw code so the
        # admin can always match against asset / BIOS records if needed.
        $modelDisplay = if ($friendlyModel -ne $rawModel) {
            "$friendlyModel  ($rawModel)"
        } else {
            $rawModel
        }
        # ──────────────────────────────────────────────────────────────────

        Clear-Host
        Write-Host "System Information for: $ComputerName" -ForegroundColor Green
        Write-Host "---------------------------------------" -ForegroundColor Green
        Write-Host "Manufacturer : $rawManufacturer"
        Write-Host "Model        : $modelDisplay"
        Write-Host "Serial Number: $($computerBIOS.SerialNumber)"
        Write-Host "CPU          : $($computerCPU.Name)"
        
        foreach ($drive in $drivesInfo) {
            Write-Host "`nDrive Letter: $($drive.DriveLetter)" -ForegroundColor Cyan
            Write-Host "  Capacity    : $($drive.CapacityGB) GB"
            Write-Host "  Free Space  : $($drive.FreeSpaceGB) GB ($($drive.FreeSpacePct)%)"
            Write-Host "  Type        : $($drive.DriveType)"
            Write-Host "  Model       : $($drive.Model)"
            if ($drive.SerialNumber) {
                Write-Host "  Serial Number: $($drive.SerialNumber)"
            }
        }
        
        Write-Host "`nRAM             : $([math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)) GB"
        Write-Host "Operating System: $($computerOS.Caption)"
        Write-Host "Windows Build   : $($windowsInfo.Build)"
        Write-Host "Feature Update  : $($windowsInfo.FeatureUpdate)"
        
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
        Write-Host "Last Reboot : $($lastBootTime.ToString("dd/MM/yyyy HH:mm:ss"))"
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

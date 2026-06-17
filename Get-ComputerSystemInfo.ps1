# Local and Remote System Information v12
# Cross-platform (Windows 7 and above) with PowerShell v2+ compatibility
# Shows details of currently running PC
# Written by Erez Schwartz
# v12: Fully verified for native PS v2 compliance by removing all inline 'if' 
#      assignment expressions which cause parsing errors on legacy engines.

function Get-PowerShellVersion {
    return $PSVersionTable.PSVersion.Major
}

function Get-OSVersion {
    param ([string]$ComputerName)
    
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName -ErrorAction Stop
        $osVersion = [Version]$os.Version
        
        $result = New-Object PSObject
        Add-Member -InputObject $result -MemberType NoteProperty -Name Major             -Value $osVersion.Major
        Add-Member -InputObject $result -MemberType NoteProperty -Name Minor             -Value $osVersion.Minor
        Add-Member -InputObject $result -MemberType NoteProperty -Name Build             -Value $osVersion.Build
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

    $result = New-Object PSObject
    Add-Member -InputObject $result -MemberType NoteProperty -Name Build         -Value "Unknown"
    Add-Member -InputObject $result -MemberType NoteProperty -Name FeatureUpdate -Value "Unknown"

    try {
        if ($ComputerName -eq "localhost" -or $ComputerName -eq $env:COMPUTERNAME) {
            $regInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
            
            # Pure PS v2 compliant block assignment
            if ($regInfo.CurrentBuild -and $regInfo.UBR) { 
                $buildNumber = "$($regInfo.CurrentBuild).$($regInfo.UBR)" 
            } else { 
                $buildNumber = $regInfo.CurrentBuild 
            }
            
            if ($regInfo.DisplayVersion) { 
                $featureUpdate = $regInfo.DisplayVersion 
            } elseif ($regInfo.ReleaseId) { 
                $featureUpdate = $regInfo.ReleaseId 
            } else { 
                $featureUpdate = "Not Available" 
            }
            
            $result.Build = $buildNumber
            $result.FeatureUpdate = $featureUpdate
        } 
        else {
            # Remote parsing via WMI Registry Provider (Pure DCOM)
            $reg = [WMIClass]"\\$ComputerName\root\default:StdRegProv"
            $HKLM = 2147483650
            $key = "SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            
            $currentBuild = ($reg.GetStringValue($HKLM, $key, "CurrentBuild")).sValue
            $ubr = ($reg.GetDWORDValue($HKLM, $key, "UBR")).uValue
            $displayVersion = ($reg.GetStringValue($HKLM, $key, "DisplayVersion")).sValue
            $releaseId = ($reg.GetStringValue($HKLM, $key, "ReleaseId")).sValue

            if ($currentBuild) {
                if ($null -ne $ubr) { $result.Build = "$currentBuild.$ubr" } else { $result.Build = $currentBuild }
            }
            if ($displayVersion) {
                $result.FeatureUpdate = $displayVersion
            } elseif ($releaseId) {
                $result.FeatureUpdate = $releaseId
            } else {
                $result.FeatureUpdate = "Not Available"
            }
        }
    }
    catch {
        Write-Host "Error retrieving Windows registry update info for $ComputerName : $_" -ForegroundColor Red
    }
    return $result
}

function Get-FriendlyModelName {
    param(
        [string]$ComputerName,
        [string]$Manufacturer,   
        [string]$RawModel        
    )

    $friendly = $null

    if ($Manufacturer -match "LENOVO") {
        try {
            $csp = Get-WmiObject -Class Win32_ComputerSystemProduct -ComputerName $ComputerName -ErrorAction SilentlyContinue
            if ($csp.Version -and $csp.Version.Trim() -ne "" -and $csp.Version.Trim() -ne "None") {
                $friendly = $csp.Version.Trim()
            }
        }
        catch { }

        if (-not $friendly) {
            try {
                $bb = Get-WmiObject -Class Win32_BaseBoard -ComputerName $ComputerName -ErrorAction SilentlyContinue
                if ($bb.Product -and $bb.Product.Trim() -ne "") {
                    $friendly = $bb.Product.Trim()
                }
            }
            catch { }
        }
    }

    if (-not $friendly) {
        $friendly = $RawModel
    }

    $cleanManufacturer = ($Manufacturer -replace "Inc\.|Corp\.|Co\.|Ltd\.|,", "").Trim()
    $words = $cleanManufacturer -split "\s+"
    foreach ($word in $words) {
        if ($word.Length -gt 2 -and $friendly -imatch "^\s*$([regex]::Escape($word))\s+") {
            $friendly = ($friendly -ireplace "^\s*$([regex]::Escape($word))\s+", "").Trim()
        }
    }

    return $friendly
}

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
            $diskDrive = $storageProps = $pnpEntity = $null
            
            $diskDrive = Get-WmiObject -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$($logicalDisk.DeviceID)'} WHERE AssocClass = Win32_LogicalDiskToPartition" -ComputerName $ComputerName |
                ForEach-Object { 
                    Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($_.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition" -ComputerName $ComputerName 
                }
            
            if ($diskDrive) {
                # Handle potential collections safely for PS v2 property extraction
                $targetDrive = $diskDrive | Select-Object -First 1
                $escapedDevID = $targetDrive.DeviceID -replace '\\', '\\\\'
                $storageProps = Get-WmiObject -Class Win32_DiskDrive -ComputerName $ComputerName -Filter "DeviceID = '$escapedDevID'" -ErrorAction SilentlyContinue
                
                if ($storageProps -and $storageProps.PNPDeviceID) {
                    $escapedPNP = $storageProps.PNPDeviceID -replace '\\', '\\\\'
                    $pnpEntity = Get-WmiObject -Class Win32_PnPEntity -ComputerName $ComputerName -Filter "PNPDeviceID = '$escapedPNP'" -ErrorAction SilentlyContinue
                }
                
                if ($targetDrive.Model) { $model = $targetDrive.Model.Trim() } else { $model = "Unknown" }
                $hasSCSISuffix = $model -match "SCSI Disk Device$"
                if ($hasSCSISuffix) { $model = ($model -replace "SCSI Disk Device$", "").Trim() }
                if ($model -match "^ADAT\s*SP") { $model = $model -replace "^ADAT\s*SP", "ADATA SP" }
                $model = ($model -replace "\s+", " ").Trim()
                if ($hasSCSISuffix) { $model = "$model SCSI Disk Device" }
                
                $driveType = "HDD"
                try {
                    if ($storageProps) {
                        if (($pnpEntity -and $pnpEntity.PNPClass -eq "NVME") -or 
                            $storageProps.InterfaceType -eq "NVME" -or
                            ($pnpEntity -and $pnpEntity.Name -match "NVM Express")) {
                            $driveType = "NVMe"
                        }
                        elseif ($storageProps.InterfaceType -eq "SCSI" -or $storageProps.InterfaceType -eq "IDE") {
                            $diskPerf = Get-WmiObject -Class Win32_DiskPerformance -ComputerName $ComputerName -Filter "Name = '$escapedDevID'" -ErrorAction SilentlyContinue
                            if (($diskPerf -and $diskPerf.AvgDiskSecPerTransfer -lt 0.015) -or
                                $storageProps.MediaType -match "SSD" -or
                                $storageProps.Capabilities -contains 4) {
                                $driveType = "SSD"
                            }
                        }
                    }
                }
                catch { Write-Verbose "Error detecting drive type through WMI: $_" }
                
                if ($targetDrive.SerialNumber) { $serialNum = $targetDrive.SerialNumber.Trim() } else { $serialNum = "" }

                $drivesInfo += New-DriveObject `
                    -DriveLetter  $logicalDisk.DeviceID `
                    -CapacityGB   ([math]::Round($logicalDisk.Size / 1GB, 2)) `
                    -FreeSpaceGB  ([math]::Round($logicalDisk.FreeSpace / 1GB, 2)) `
                    -FreeSpacePct ([math]::Round(($logicalDisk.FreeSpace / $logicalDisk.Size) * 100, 2)) `
                    -DriveType    $driveType `
                    -Model        $model `
                    -SerialNumber $serialNum
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
        $physicalDisks   = Get-CimInstance -ClassName MSFT_PhysicalDisk -Namespace root\Microsoft\Windows\Storage -ComputerName $ComputerName -ErrorAction Stop
        $logicalDisks    = Get-CimInstance -ClassName Win32_LogicalDisk  -ComputerName $ComputerName -Filter "DriveType = 3" -ErrorAction Stop
        $partitionToDisk = Get-CimInstance -ClassName MSFT_Partition      -Namespace root\Microsoft\Windows\Storage -ComputerName $ComputerName -ErrorAction Stop
        
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
    
    try {
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem  -ComputerName $ComputerName -ErrorAction Stop
        $computerBIOS   = Get-WmiObject -Class Win32_BIOS            -ComputerName $ComputerName -ErrorAction Stop
        $computerOS     = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName -ErrorAction Stop
        
        $computerCPU    = Get-WmiObject -Class Win32_Processor       -ComputerName $ComputerName -ErrorAction SilentlyContinue | Select-Object -First 1
        $windowsInfo    = Get-WindowsVersionInfo -ComputerName $ComputerName
        $drivesInfo     = Get-DriveInfo          -ComputerName $ComputerName

        $rawManufacturer = $computerSystem.Manufacturer.Trim()
        $rawModel        = $computerSystem.Model.Trim()
        $friendlyModel   = Get-FriendlyModelName -ComputerName $ComputerName `
                                                  -Manufacturer $rawManufacturer `
                                                  -RawModel     $rawModel

        if ($friendlyModel -ne $rawModel) { 
            $modelDisplay = "$friendlyModel  ($rawModel)" 
        } else { 
            $modelDisplay = $rawModel 
        }

        Clear-Host
        Write-Host "System Information for: $ComputerName" -ForegroundColor Green
        Write-Host "---------------------------------------" -ForegroundColor Green
        Write-Host "Manufacturer : $rawManufacturer"
        Write-Host "Model        : $modelDisplay"
        Write-Host "Serial Number: $($computerBIOS.SerialNumber)"
        if ($computerCPU) { Write-Host "CPU          : $($computerCPU.Name)" }
        
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
        
        if ($ComputerName -eq "localhost" -or $ComputerName -eq $env:COMPUTERNAME) {
            $loggedOnUser = "$env:USERDOMAIN\$env:USERNAME"
        } else {
            $loggedOnUser = $computerSystem.UserName
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
    $null = Read-Host
}

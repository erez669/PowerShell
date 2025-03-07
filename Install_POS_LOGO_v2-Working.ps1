# Elevate the script if not run as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "& '" + $MyInvocation.MyCommand.Definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    break
}

$VerbosePreference = 'Continue'
Clear-Host

# Initialize essential variables
$hostname = $env:COMPUTERNAME
$initialDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Kill certain processes
Stop-Process -Name "GroceryWinPos", "sco", "java" -Force -ErrorAction SilentlyContinue -Verbose

# Pause for effect
Start-Sleep -Seconds 10 -Verbose

# Execute an application
Start-Process -FilePath "$initialDir\kupalogo.exe" -NoNewWindow:$false -Wait:$false -Verbose

# Active Directory Setup
Add-Type -AssemblyName "System.DirectoryServices"
$branch = $hostname.Substring(4, 3)
$root = New-Object System.DirectoryServices.DirectoryEntry("LDAP://rootDse")
$domain = $root.dnsHostName
$branchGroup = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$domain/cn=branch_$branch,ou=branch groups,ou=group objects,ou=OUs,dc=posprod,dc=supersol,dc=co,dc=il")

# Collect group names
$collectedGroups = @()
foreach ($groupDN in $branchGroup.memberof) {
    $simpleGroupName = ($groupDN -split ',')[0] -replace 'CN=', ''
    $collectedGroups += $simpleGroupName.ToUpper()
}

# Determine the exit code based on group membership
$exitCode = 0
foreach ($groupName in $collectedGroups) {
    Write-Verbose "Processing group: $groupName"
    switch ($groupName) {
        "NET_SUPERSOL_DEAL"           { $exitCode = 2; break }
        "NET_SUPERSOL_MINE"           { $exitCode = 3; break }
        "NET_SUPERSOL_YESH_HESSED"    { $exitCode = 4; break }
        "NET_SUPERSOL_YESH"           { $exitCode = 5; break }
        "NET_SUPERSOL_EXPRESS"        { $exitCode = 6; break }
        "NET_SUPERSOL_SHAAREVACHA"    { $exitCode = 7; break }
        "NET_ORGANIC_MARKET"          { $exitCode = 8; break }
        "NET_SUPERSOL_NEW_PHARM"      { $exitCode = 9; break }
        "NET_SUPERSOL_GIDRON"         { $exitCode = 10; break }
        "NET_SUPERSOL_CASH_CARRY"     { $exitCode = 11; break }
        "NET_SUPERSOL_ONLINE"         { $exitCode = 12; break }
        "NET_BELA_STORE"              { $exitCode = 13; break }
        "NET_SUPERSOL_TRIGO"          { $exitCode = 14; break }
        "NET_SUPERSOL_GOOD_MARKET"    { $exitCode = 15; break }
        "NET_SUPERSOL_THEDISTRIBUTOR" { $exitCode = 16; break }
        default                       { Continue }
    }
    Write-Verbose "Exit code set to $exitCode for $groupName"
    if ($exitCode) { break }
}

Write-Host "Last LDAP Group Name Processed: $groupName"  # This will show the last group processed that set an exit code
Write-Host "Exit Code: $exitCode"  # This will display the final exit code

# Map $exitCode to $logo2 (Modify this mapping as needed)
$logo2 = $exitCode
Write-Host "Logo2 is set to $logo2"

# Mapping from exitCode to executable names for non-SCO/CSS
$exitCodeToExeMap = @{
    2  = "Screen_Shufersal.exe"
    3  = "Shufersal_Mine.exe"
    4  = "Screen_Yesh.exe"
    5  = "Screen_Yesh.exe"
    6  = "Express.exe"
    9  = "Be.exe"
    11 = "Screen_CashNCarry.exe"
    13 = "Go to Bela logic"
    14 = "Trigo.exe"
    15 = "Screen_GoodMarket.exe"
    16 = "Screen_TheDistributor.exe"
    #... (Add other cases)
}

# Mapping from logo2 to the correct exe names for SCO/CSS
$exitCodeToSCOFileMap = @{
    2 =  "Shufersal.exe"
    3 =  "Shufersal.exe" 
    4 =  "YESH_Hessed.exe"
    5 =  "YESH_Bashchuna.exe"
    6 =  "Shufersal.exe"
    7 =  "Shaarey_Revacha.exe"
    9 =  "NEWPHARM.exe"
    11 = "Shufersal.exe"
    13 = "NEWPHARM.exe"
    14 = "Shufersal.exe"
    15 = "GoodMarket.exe"
    16 = "TheDistributor.exe"
}

# Mapping from exitCode to filename
$exitCodeToFileMap = @{
    2 = "superdilSmall"
    3 = "supermySmall"
    4 = "yeshhesedsmall"
    5 = "yeshlogosmall"
    6 = "superexpressSmall"
    7 = "RevahaSmall"
    9 = "NewPharmsmall"
    11 = "CashNCarry"
    13 = "Bela"
    14 = "Trigo"
    15 = "GoodMarket"
    16 = "TheDistributor"
}

# Fetch the filename based on exitCode
$fileName = $exitCodeToFileMap[$exitCode]
Write-Host "Debug: Filename is $fileName"
$correctExeName = $exitCodeToSCOFileMap[$exitCode]
Write-Host "Filename inside SCO/CSS block: $correctExeName"

$computerNameSuffix = $env:COMPUTERNAME.Substring($env:COMPUTERNAME.Length - 3).ToUpper()
Write-Verbose "Before checking computerNameSuffix"

if ($computerNameSuffix -eq "SCO" -or $computerNameSuffix -eq "CSS") {
    $version = (Get-WmiObject -Query "SELECT * FROM Win32_OperatingSystem").Version
    # $architecture = (Get-WmiObject -Query "SELECT * FROM Win32_Processor").AddressWidth
    Write-Verbose "OS version is $version"
    
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition  # Get script location

    $versionMajorMinor = ($version -split "\.")[0..1] -join "."

    if ($versionMajorMinor -eq "10.0") {
        $sfxPath = Join-Path $scriptRoot "SCO_SFX_10"
        $programPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\PRINTIMAGES\"
        Write-Verbose "Setting paths for OS 10.0"
        Write-Verbose "About to copy files..."
        Copy-Item -Path "\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\POS\-POS-LOGO-\Printing\*" -Destination $programPath -Force -Verbose
        Write-Verbose "Files copied."
    } elseif ($versionMajorMinor -eq "6.1") {
        $sfxPath = Join-Path $scriptRoot "SCO_SFX"
        $programPath = "C:\Program Files\Retalix\SCO.NET\App\PRINTIMAGES\"
        Write-Verbose "Setting paths for OS 6.1"
        Write-Verbose "About to copy files..."
        Copy-Item -Path "\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\POS\-POS-LOGO-\Printing\*" -Destination $programPath -Force -Verbose
        Write-Verbose "Files copied."
    } else {
        Write-Verbose "OS version does not match either 10.0 or 6.1."
        exit 1
    }
    }

# Determine correct executable based on the computer name suffix
if ($computerNameSuffix -eq "SCO" -or $computerNameSuffix -eq "CSS") {
    $correctExeName = $exitCodeToSCOFileMap[$exitCode]
    $executable = $correctExeName
    Write-Verbose "Determined executable to run (SCO/CSS): $correctExeName"
} else {
    $correctExeName = $exitCodeToExeMap[$exitCode]
    $executable = $correctExeName
    Write-Verbose "Determined executable to run (Standard POS): $correctExeName"
}

# Initialize $sfxPath based on $versionMajorMinor and $computerNameSuffix
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition  # Get script location
$version = (Get-WmiObject -Query "SELECT * FROM Win32_OperatingSystem").Version
$versionMajorMinor = ($version -split "\.")[0..1] -join "."

if ($computerNameSuffix -eq "SCO" -or $computerNameSuffix -eq "CSS") {
    if ($versionMajorMinor -eq "10.0") {
        $sfxPath = Join-Path $scriptRoot "SCO_SFX_10"
    } elseif ($versionMajorMinor -eq "6.1") {
        $sfxPath = Join-Path $scriptRoot "SCO_SFX"
    }
} else {
    $sfxPath = $scriptRoot  # If non-SCO, the location is in the script root
}

Write-Host "Script Root: $scriptRoot"
Write-Host "Version: $version"
Write-Host "Version Major Minor: $versionMajorMinor"
Write-Host "sfxPath: $sfxPath"

# Check if all variables are set before executing
if ($sfxPath -and $correctExeName) {
    $fullPathToDirExe = Join-Path $sfxPath $correctExeName
    Write-Host "Checking executable path: $fullPathToDirExe"
    Write-Host "Full Path to Dir Exe: $fullPathToDirExe"
    
    if (Test-Path $fullPathToDirExe) {
        Start-Process $fullPathToDirExe -NoNewWindow:$false -Wait:$false
        Write-Host "Executable exists."
    } else {
        Write-Host "Executable not found at $fullPathToDirExe"
    }
} else {
    Write-Host "One or more variables for executable path are not set."
}

# Determine the XML path based on OS version and computer name suffix
if ($computerNameSuffix -eq "SCO" -or $computerNameSuffix -eq "CSS") {
    if ($versionMajorMinor -eq "10.0") {
        $xmlPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\DevicesConfig.xml"
    } elseif ($versionMajorMinor -eq "6.1") {
        $xmlPath = "C:\Program Files\Retalix\SCO.NET\App\DevicesConfig.xml"
    }

    # Log and check if the XML path exists
    Write-Host "Checking XML Path: $xmlPath"
    if (Test-Path $xmlPath) {
        [xml]$xmlContent = Get-Content -Path $xmlPath
        $bitmapNode = $xmlContent.SelectSingleNode("//Printer/@BitmapFile")
        
        if ($null -ne $bitmapNode) {
            $fileName = $exitCodeToFileMap[$logo2]
            $newBitmapValue = Join-Path (Split-Path $xmlPath) "PRINTIMAGES\$fileName.bmp"
            
            # Update the BitmapFile attribute
            $bitmapNode.Value = $newBitmapValue
            
            # Save the changes back to the XML file
            $xmlContent.Save($xmlPath)
            Write-Host "BitmapFile attribute updated to $newBitmapValue."
        } else {
            Write-Host "BitmapFile attribute not found in XML."
        }
    } else {
        Write-Host "XML file not found at $xmlPath."
        exit 1
    }

} else {
# Update the BitmapFile attribute based on $fileName
$newBitmapValue = "C:\Retalix\WinGPOS\files\Images\Printing\$fileName.bmp"

# Execute the mapped executable if not null
if ($null -ne $executable) {
    if ($executable -eq "Go to Bela logic" -and $exitCode -eq 13) {
        # Bela-specific logic
        $xmlPath = "C:\retalix\wingpos\Files\devices\EpsonOPOSConfig.xml"
        if (Test-Path $xmlPath) {
            [xml]$content = Get-Content "C:\retalix\wingpos\Files\devices\EpsonOPOSConfig.xml"
            $bitmapNode = $content.SelectSingleNode("//POSDeviceList/POSPrinter") -or $content.SelectSingleNode("//Printer/@BitmapFile")
            if ($bitmapNode -ne $null) {
                $tokens = ($bitmapNode.Value -split '\.')[6]
                $bmpPath = "C:\Retalix\WinGPOS\files\Images\Printing\$tokens.bmp"
                if (Test-Path $bmpPath) {
                    # Delete the existing backup file if it exists
                    $backupPath = "$xmlPath.bak"
                    if (Test-Path $backupPath) {
                    Write-Host "Deleting existing backup at $backupPath."
                    Remove-Item -Path $backupPath -Force -Verbose
                    }

                    # Create the backup by copying the XML file
                    try {
                    [System.IO.File]::Copy($xmlPath, $backupPath, $true)
                    Write-Host "Successfully created or overwritten the backup."
                    } catch {
                    Write-Host "Failed to create or overwrite backup: $_"
                    }

                    Add-Content -Path "c:\logo.log" -Value "start Be_Logo.bat"
                    cmd.exe /c "copy Bela.bmp C:\Retalix\WinGPOS\files\Images\Printing\ /y"
                    $bitmapNode.Value = "C:\Retalix\WinGPOS\files\Images\Printing\Bela.bmp"
                    $content.Save($xmlPath)
                    Add-Content -Path "c:\logo.log" -Value "end Be_Logo.bat"
                    
                    # Create setposlogo.txt
                    $txtFilePath = "C:\Retalix\wingpos\Files\Devices\setposlogo.txt"
                    $txtContent = @"
XML changes applied.
XML Path: $xmlPath
Backup Path: $xmlPath.bak
Bitmap Node Value: $($bitmapNode.Value)
BMP Path: $bmpPath
"@
                    [System.IO.File]::WriteAllText($txtFilePath, $txtContent)
                }
            } else {
                Write-Host "BitmapFile not found in config"
            }
        } else {
            Write-Host "Config file not found"
        }
    } else {
        # For all other executables and exit codes
        Start-Process $executable
    }
}

# Copy files if the directory exists
if (Test-Path "c:\retalix") {
    cmd.exe /c "xcopy /y `"`"\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\POS\-POS-LOGO-\Printing\*`"`" `"`"c:\retalix\wingpos\Files\Images\Printing\`"`""
    Write-Verbose "Files copied."
}

# Load the XML file into $content if not already loaded
$xmlPath = "C:\retalix\wingpos\Files\devices\EpsonOPOSConfig.xml"
if ($null -eq $content) {
    [xml]$content = Get-Content $xmlPath
}

# Check if XML file exists
if (Test-Path $xmlPath) {
    # Existing logic to find the POSPrinter node
    $printerNode = $content.SelectSingleNode("//POSDeviceList/POSPrinter")
    if ($null -ne $printerNode) {
        Write-Verbose "Found POSPrinter node."
        $backupPath = "$xmlPath.bak"
        if (Test-Path $backupPath) {
        Write-Host "Deleting existing backup at $backupPath."
        Remove-Item -Path $backupPath -Force -Verbose
        }

        # Create the backup by copying the XML file
        try {
        [System.IO.File]::Copy($xmlPath, $backupPath, $true)
        Write-Host "Successfully created or overwritten the backup."
        } catch {
        Write-Host "Failed to create or overwrite backup: $_"
        }

        # Get the current BitmapFile value
        $currentBitmapValue = $printerNode.GetAttribute('BitmapFile')
        Write-Verbose "Current BitmapFile value: $currentBitmapValue"

        # Set the BitmapFile attribute
        $printerNode.SetAttribute('BitmapFile', $newBitmapValue)
        $content.Save($xmlPath)

        Write-Verbose "BitmapFile attribute updated. New value: $newBitmapValue"
        
        # Create setposlogo.txt
        $txtFilePath = "C:\Retalix\wingpos\Files\Devices\setposlogo.txt"
        $txtContent = @"
XML changes applied.
XML Path: $xmlPath
Backup Path: $xmlPath.bak
Current BitmapFile value: $currentBitmapValue
New BitmapFile value: $newBitmapValue
"@
        [System.IO.File]::WriteAllText($txtFilePath, $txtContent)
    } else {
        Write-Verbose "POSPrinter node not found."
    }
} else {
    Write-Host "XML file not found"
}

}

exit 0

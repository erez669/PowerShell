$VerbosePreference = 'Continue'

# Set hostname and initialize variables to $null
$hostname = $env:COMPUTERNAME
$logo2 = $null
$xmlPath = $null 
$backupPath = $null

# Kill tasks
Stop-Process -Name "GroceryWinPos" -Force -ErrorAction SilentlyContinue -Verbose
Stop-Process -Name "sco" -Force -ErrorAction SilentlyContinue -Verbose
Stop-Process -Name "java" -Force -ErrorAction SilentlyContinue -Verbose

# Sleep (Replicating 'call :sleep' - assuming it's a sleep function)
Start-Sleep -Seconds 10 -Verbose

# Run kupalogo.exe
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
Start-Process -FilePath "$scriptDir\kupalogo.exe" -NoNewWindow:$false -Wait:$false
Write-Verbose "After kupalogo.exe"

# Initialize
Add-Type -AssemblyName "System.DirectoryServices"
$branch = $hostname.Substring(4, 3)
$exitCode = 0

# LDAP Query
$root = New-Object System.DirectoryServices.DirectoryEntry("LDAP://rootDse")
$domain = $root.dnsHostName
$branchGroup = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$domain/cn=branch_$branch,ou=branch groups,ou=group objects,ou=OUs,dc=posprod,dc=supersol,dc=co,dc=il")

# Loop through each group
foreach ($groupDN in $branchGroup.memberof) {
    $group = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$domain/$groupDN")
    switch ($group.Name[0].ToUpper())
    {
        "NET_SUPERSOL_DEAL"          { $exitCode = 2; break }
        "NET_SUPERSOL_MINE"          { $exitCode = 3; break }
        "NET_SUPERSOL_YESH_HESSED"   { $exitCode = 4; break }
        "NET_SUPERSOL_YESH"          { $exitCode = 5; break }
        "NET_SUPERSOL_EXPRESS"       { $exitCode = 6; break }
        "NET_SUPERSOL_SHAAREVACHA"   { $exitCode = 7; break }
        "NET_ORGANIC_MARKET"         { $exitCode = 8; break }
        "NET_SUPERSOL_NEW_PHARM"     { $exitCode = 9; break }
        "NET_SUPERSOL_GIDRON"        { $exitCode = 10; break }
        "NET_SUPERSOL_CASH_CARRY"    { $exitCode = 11; break }
        "NET_SUPERSOL_ONLINE"        { $exitCode = 12; break }
        "NET_BELA_STORE"             { $exitCode = 13; break }
        "NET_SUPERSOL_TRIGO"         { $exitCode = 14; break }
        "NET_SUPERSOL_GOOD_MARKET"   { $exitCode = 15; break }
    }
}

Write-Host "Group Name: $($group.Name[0])"

# Map $exitCode to $logo2 (Modify this mapping as needed)
$logo2 = $exitCode
Write-Host "Logo2 is set to $logo2"

# Get script's directory
$scriptDir = Split-Path $script:MyInvocation.MyCommand.Path

# Map $exitCode to executable name
Write-Host "Exit Code: $exitCode"
switch ($exitCode) {
    2  { $executable = Join-Path $scriptDir "Screen_Shufersal.exe" }
    3  { $executable = Join-Path $scriptDir "Shufersal_Mine.exe" }
    4  { $executable = Join-Path $scriptDir "Screen_Yesh.exe" }
    5  { $executable = Join-Path $scriptDir "Screen_Yesh.exe" }
    6  { $executable = Join-Path $scriptDir "Express.exe" }
    9  { $executable = Join-Path $scriptDir "Be.exe" }
    11 { $executable = Join-Path $scriptDir "Screen_CashNCarry.exe" }
    13 { $executable = Join-Path $scriptDir "Go to Bela logic" }
    14 { $executable = Join-Path $scriptDir "Trigo.exe" }
    15 { $executable = Join-Path $scriptDir "Screen_GoodMarket.exe" }
    #... (Add other cases)
}

# Now print the executable
Write-Host "Executable to run: $executable"

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
    16 = "superexpressSmall"
}

# Fetch the filename based on exitCode
$fileName = $exitCodeToFileMap[$exitCode]

$computerNameSuffix = $env:COMPUTERNAME.Substring($env:COMPUTERNAME.Length - 3).ToUpper()
Write-Verbose "Before checking computerNameSuffix"

if ($computerNameSuffix -eq "SCO" -or $computerNameSuffix -eq "CSS") {
    $version = (Get-WmiObject -Query "SELECT * FROM Win32_OperatingSystem").Version
    $architecture = (Get-WmiObject -Query "SELECT * FROM Win32_Processor").AddressWidth
    Write-Verbose "OS version is $version"
    
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition  # Get script location
    $dir = "Shufersal"

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

    if ($versionMajorMinor -eq "10.0" -or $versionMajorMinor -eq "6.1") {
        
        switch ($logo2) {
            "NewPharmsmall"  { $dir = "NEWPHARM" }
            "RevahaSmall"    { $dir = "Shaarey_Revacha" }
            "yeshhesedsmall" { $dir = "YESH_Hessed" }
            "yeshlogosmall"  { $dir = "YESH_Bashchuna" }
            "GoodMarket"     { $dir = "GoodMarket" }
        }

        # Set the full path to the executable based on $dir
        $fullPathToDirExe = Join-Path $sfxPath "$dir.exe"
        Write-Host "Checking executable path: $fullPathToDirExe"

        # Check if the path exists
        if (Test-Path $fullPathToDirExe) {
        Start-Process $fullPathToDirExe -NoNewWindow:$false -Wait:$false
        Write-Host "Executable exists."
        } else {
        Write-Host "Executable not found at $fullPathToDirExe"
        Write-Host "Executable doesn't exist."
        }

# Check if $env:logo2 is set
if (-not $logo2 -or $logo2 -eq "") {
    Write-Host "Environment variable logo2 is not set. Exiting."
    exit 1
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
        
        if ($bitmapNode -ne $null) {
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
}

} else {
# Update the BitmapFile attribute based on $fileName
$newBitmapValue = "C:\Retalix\WinGPOS\files\Images\Printing\$fileName.bmp"

# Execute the mapped executable if not null
if ($executable -ne $null) {
    if ($executable -eq "Go to Bela logic" -and $exitCode -eq 13) {
        # Bela-specific logic
        $xmlPath = "C:\retalix\wingpos\Files\devices\EpsonOPOSConfig.xml"
        if (Test-Path $xmlPath) {
            [xml]$content = Get-Content "C:\retalix\wingpos\Files\devices\EpsonOPOSConfig.xml"
            $bitmapNode = $content.SelectSingleNode("//POSPrinter/@BitmapFile") -or $content.SelectSingleNode("//Printer/@BitmapFile")
            if ($bitmapNode -ne $null) {
                $tokens = ($bitmapNode.Value -split '\.')[6]
                $bmpPath = "C:\Retalix\WinGPOS\files\Images\Printing\$tokens.bmp"
                if (Test-Path $bmpPath) {
                    # Delete the existing backup file if it exists
                    $backupPath = "$xmlPath.bak"
                    if (Test-Path $backupPath) {
                    Remove-Item $backupPath -Force -Verbose
                    }

                    # Create the backup by copying the XML file
                    [System.IO.File]::Copy($xmlPath, $backupPath)
                    Write-Verbose "Backup saved at $backupPath"

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
if ($content -eq $null) {
    [xml]$content = Get-Content $xmlPath
}

# Check if XML file exists
if (Test-Path $xmlPath) {
    # Existing logic to find the POSPrinter node
    $printerNode = $content.SelectSingleNode("//POSPrinter")
    if ($printerNode -ne $null) {
        Write-Verbose "Found POSPrinter node."
        $backupPath = "$xmlPath.bak"
        if (Test-Path $backupPath) {
        Remove-Item $backupPath -Force -Verbose
    }

        # Create the backup by copying the XML file
        [System.IO.File]::Copy($xmlPath, $backupPath)
        Write-Verbose "Backup saved at $backupPath"

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

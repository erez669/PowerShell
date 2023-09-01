# Change directory to script's location
Set-Location $PSScriptRoot

# Start the transcript
Start-Transcript -Path "$PSScriptRoot\POSLOGO_Results.txt"

# Terminate processes
cmd /c taskkill /f /im "GroceryWinPos.exe" /t
cmd /c taskkill /f /im "sco.exe" /t
cmd /c taskkill /f /im "java.exe" /t

# Pause for 10 seconds
Start-Sleep -Seconds 10 -Verbose

# Run kupalogo.exe
Start-Process "$PSScriptRoot\kupalogo.exe"

# Get Computer Info
$computer = Get-WmiObject Win32_ComputerSystem
$computerName = $computer.Name
$branchNumber = $computerName.Split('-')[1]

# LDAP group search
$ldapPath = "LDAP://OU=Branch Groups,OU=Group Objects,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"
$groupCN = "Branch_$branchNumber"

$dirEntry = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
$search = New-Object System.DirectoryServices.DirectorySearcher($dirEntry)

$search.Filter = "(CN=$groupCN)"
$search.PropertiesToLoad.Add("memberOf")

$group = $search.FindOne()

# Initialize logo2 as default
$logo2 = "default"

# Check group memberships and set $logo2
foreach ($groupMembership in $group.Properties.memberof) {
  $groupName = ($groupMembership -split ',')[0].Split('=')[1]
  if ($groupName -match "net_supersol_(.+)") {
    $logo2 = $matches[1]
    break
  }
}

# Execute specific programs based on $logo2 value
switch ($logo2) {
    "NewPharmsmall" { Start-Process "Be.exe" }
    "superdilSmall" { Start-Process "Screen_Shufersal.exe" }
    "supermySmall" { Start-Process "Shufersal_Mine.exe" }
    "superexpressSmall" { Start-Process "Express.exe" }
    "yeshhesedsmall" { Start-Process "Screen_Yesh.exe" }
    "yeshlogosmall" { Start-Process "Screen_Yesh.exe" }
    "CashNCarry" { Start-Process "Screen_CashNCarry.exe" }
    "GoodMarket" { Start-Process "Screen_GoodMarket.exe" }
    "Trigo" { Start-Process "Trigo.exe" }
    "Bela" {
        $xmlPath = "C:\retalix\wingpos\Files\devices\EpsonOPOSConfig.xml"
        if (Test-Path $xmlPath) {
            $bitmapFiles = Select-String -Path $xmlPath -Pattern "BitmapFile" -SimpleMatch
            if ($null -ne $bitmapFiles) {
                $existingBitmaps = $bitmapFiles -replace '.*BitmapFile="(.+?)\..*','$1'
                foreach ($existingBitmap in $existingBitmaps) {
                    $existingBitmapPath = "C:\Retalix\WinGPOS\files\Images\Printing\$existingBitmap.bmp"
                    if (Test-Path $existingBitmapPath) {
                        cmd /c copy $xmlPath "$xmlPath.bak" /y
                        $xml = New-Object XML
                        $xml.Load($xmlPath)
                        $node = $xml.SelectSingleNode("//POSPrinter/@BitmapFile") -or $xml.SelectSingleNode("//Printer/@BitmapFile")
                        if ($node -ne $null) {
                            $node.'#text' = "C:\Retalix\WinGPOS\files\Images\Printing\$logo2.bmp"
                            $xml.Save($xmlPath)
                        }
                    }
                }
                cmd /c echo "start Be_Logo.bat" >> "c:\logo.log"
                cmd /c copy "Bela.bmp" "C:\Retalix\WinGPOS\files\Images\Printing\" /y
                cmd /c xmlu.exe edit $xmlPath /REP:I /S:Bela.xml
                cmd /c echo "end Be_Logo.bat" >> "c:\logo.log"
            } else {
                Write-Host "BitmapFile not found in config."
            }
        } else {
            Write-Host "Config file not found."
        }
    }
    default { Write-Host "No matching program found. Exiting." }
}

# Copy files if "c:\retalix" exists
if (Test-Path "c:\retalix") {
    cmd /c xcopy /y "\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\POS\-POS-LOGO-\Printing\*" "c:\retalix\wingpos\Files\Images\Printing\"
}

# XML logic for EpsonOPOSConfig.xml
$xmlPath = "C:\retalix\wingpos\Files\devices\EpsonOPOSConfig.xml"
if (Test-Path $xmlPath) {
    $xmlContent = Get-Content $xmlPath -Raw
    if ($xmlContent -match 'BitmapFile') {
        $xml = [xml]$xmlContent
        $bitmapFileNode = $xml.SelectSingleNode('//POSPrinter/@BitmapFile')
        if ($bitmapFileNode -eq $null) {
            $bitmapFileNode = $xml.SelectSingleNode('//Printer/@BitmapFile')
        }

        if ($bitmapFileNode -ne $null) {
            $existingValue = $bitmapFileNode.'#text'
            $existingBitmapPath = "C:\Retalix\WinGPOS\files\Images\Printing\$existingValue.bmp"
            if (Test-Path $existingBitmapPath) {
                cmd /c copy $xmlPath "$xmlPath.bak" /y
                $bitmapFileNode.'#text' = $logo2
                $xml.Save($xmlPath)
                Add-Content "C:\retalix\wingpos\files\devices\setposlogo.log" "Replaced $existingValue with $logo2 in $xmlPath"
            }
        }
    } else {
        Add-Content "C:\retalix\wingpos\files\devices\setposlogo.log" "BitmapFile not found in XML."
    }
}

# Check computer name last 3 characters ending with SCO or CSS
$computerName = $env:computername
$last3Letters = $computerName.Substring($computerName.Length - 3)

# Get the OS version
$version = [System.Environment]::OSVersion.Version
$versionString = "$($version.Major).$($version.Minor)"
    
    if ($versionString -eq "10.0") {
    if ($last3Letters -eq "SCO" -or $last3Letters -eq "CSS") {
        # SCO10 logic
        cmd /c xcopy /y "\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\POS\-POS-LOGO-\Printing" "C:\Program Files (x86)\Retalix\SCO.NET\App\PRINTIMAGES\"
        cmd /c taskkill /f /im "sco.exe" /t
        cmd /c taskkill /f /im "java.exe" /t

        Set-Location "$PSScriptRoot\SCO_SFX_10" # current location for this folder
        $dir = "Shufersal"
        switch ($logo2) {
            "NewPharmsmall" { $dir = "NEWPHARM" }
            "RevahaSmall" { $dir = "Shaarey_Revacha" }
            "yeshhesedsmall" { $dir = "YESH_Hessed" }
            "yeshlogosmall" { $dir = "YESH_Bashchuna" }
            "GoodMarket" { $dir = "GoodMarket" }
        }

        Start-Process "$dir.exe"

        # Replace Bitmap Files
        $xmlPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\DevicesConfig.xml"
        if (Test-Path $xmlPath) {
            $xmlContent = Get-Content $xmlPath -Raw
            if ($xmlContent -match 'BitmapFile') {
                $xml = [xml]$xmlContent
                $bitmapFileNode = $xml.SelectSingleNode('//POSPrinter/@BitmapFile')
                if ($bitmapFileNode -eq $null) {
                    $bitmapFileNode = $xml.SelectSingleNode('//Printer/@BitmapFile')
                }
                if ($bitmapFileNode -ne $null) {
                    $existingValue = $bitmapFileNode.'#text'
                    $existingBitmapPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\PRINTIMAGES\$existingValue.bmp"
                    if (Test-Path $existingBitmapPath) {
                        cmd /c copy $xmlPath "$xmlPath.bak"
                        $bitmapFileNode.'#text' = "$logo2"
                        $xml.Save($xmlPath)
                        Add-Content "C:\Program Files (x86)\Retalix\SCO.NET\App\PRINTIMAGES\setposlogo.log" "Replaced $existingValue with $logo2 in $xmlPath"
                    }
                }
            }
        }
        Add-Content "c:\logo.log" "$logo2 kupa"

        # Additional logic based on $logo2
        if ($logo2 -eq "NewPharmsmall") {
            Start-Process "Be_Sco_Logo_Update_W10.bat"
        }
    }
    elseif ($versionString -eq "6.1" -and $last3Letters -eq "SCO") {
        # SCO7 logic
        cmd /c xcopy /y "\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\POS\-POS-LOGO-\Printing" "C:\Program Files\Retalix\SCO.NET\App\PRINTIMAGES\"
        cmd /c taskkill /f /im "sco.exe" /t
        cmd /c taskkill /f /im "java.exe" /t

        Set-Location "$PSScriptRoot\SCO_SFX"  # current location for this folder
        $dir = "Shufersal"
        switch ($logo2) {
            "NewPharmsmall" { $dir = "NEWPHARM" }
            "RevahaSmall" { $dir = "Shaarey_Revacha" }
            "yeshhesedsmall" { $dir = "YESH_Hessed" }
            "yeshlogosmall" { $dir = "YESH_Bashchuna" }
            "GoodMarket" { $dir = "GoodMarket" }
        }
        Start-Process "$dir.exe"

        # Replace Bitmap Files
        $xmlPath = "C:\Program Files\Retalix\SCO.NET\App\DevicesConfig.xml"
        if (Test-Path $xmlPath) {
            $xmlContent = Get-Content $xmlPath -Raw
            if ($xmlContent -match 'BitmapFile') {
                $xml = [xml]$xmlContent
                $bitmapFileNode = $xml.SelectSingleNode('//POSPrinter/@BitmapFile')
                if ($bitmapFileNode -eq $null) {
                    $bitmapFileNode = $xml.SelectSingleNode('//Printer/@BitmapFile')
                }
                if ($bitmapFileNode -ne $null) {
                    $existingValue = $bitmapFileNode.'#text'
                    $existingBitmapPath = "C:\Program Files\Retalix\SCO.NET\App\PRINTIMAGES\$existingValue.bmp"
                    if (Test-Path $existingBitmapPath) {
                        cmd /c copy $xmlPath "$xmlPath.bak"
                        $bitmapFileNode.'#text' = "$logo2"
                        $xml.Save($xmlPath)
                        Add-Content "C:\Program Files\Retalix\SCO.NET\App\PRINTIMAGES\setposlogo.log" "Replaced $existingValue with $logo2 in $xmlPath"
                    }
                }
            }
        }
        Add-Content "c:\logo.log" "$logo2 kupa"

        # Additional logic based on $logo2
        if ($logo2 -eq "NewPharmsmall") {
            Start-Process "Be_Sco_Logo_Update.bat"
        }
    }
}

else {
    Write-Host "BitmapFile not found in config."
    exit 0
}

# Stop the transcript
Stop-Transcript
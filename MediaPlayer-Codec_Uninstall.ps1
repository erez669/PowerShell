If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}

# Check if the last three characters of the hostname are 'CSS'
if ($env:COMPUTERNAME.Substring($env:COMPUTERNAME.Length - 3).ToLower() -eq 'css') {
    Write-Output "CTM Device was detected, exiting..."
    exit 0
}

# Enable verbose output
$VerbosePreference = "Continue"

# Function to kill specified processes
function Kill-Processes {
    param (
        [string[]]$processNames
    )
    foreach ($processName in $processNames) {
        Get-Process $processName -ErrorAction SilentlyContinue | Stop-Process -Force -Verbose
    }
}

# Kill specified processes first
Kill-Processes -processNames @("sco", "java", "edgify-agent")

# Function to ensure only one folder named 'VIDEOS' exists
function Ensure-SingleVideosFolder {
    param (
        [string]$searchPath,
        [string]$correctName = "VIDEOS"
    )
    
    $videoFolders = Get-ChildItem $searchPath -Directory | Where-Object { $_.Name -like "video*" }
    $removedItemsCount = 0

    # Find if the correctly named folder exists
    $correctFolder = $videoFolders | Where-Object { $_.Name -eq $correctName }

    if ($correctFolder) {
        # If the correct folder exists, remove all other 'video*' folders
        $videoFolders | Where-Object { $_.FullName -ne $correctFolder.FullName } | ForEach-Object {
            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            $removedItemsCount++
        }
        if($removedItemsCount -gt 0){
            Write-Output "Removed $removedItemsCount 'video*' folder(s) that did not match the correct name."
        }
    } else {
        # If no correct folder exists, rename the first 'video*' folder to 'VIDEOS' and remove the rest
        $foldersToRename = $videoFolders | Sort-Object CreationTime | Select-Object -First 1
        if ($foldersToRename) {
            $newPath = Join-Path (Split-Path $foldersToRename.FullName -Parent) $correctName
            Rename-Item $foldersToRename.FullName $newPath -Force
            Write-Output "Folder renamed to '$correctName'."
            $removedItemsCount++
        }
        $videoFolders | Where-Object { $_.FullName -ne $foldersToRename.FullName } | ForEach-Object {
            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            $removedItemsCount++
        }
        if($removedItemsCount -gt 1){
            Write-Output "Removed $($removedItemsCount-1) 'video*' folder(s) after renaming one to the correct name."
        }
    }
}

# Perform folder cleanup
Ensure-SingleVideosFolder -searchPath "C:\Program Files (x86)\Retalix\SCO.NET\App\Shufersal\PPL\IMAGES\"

# Detect the system architecture and perform uninstallation if necessary
$kliteUninstallerPath = "C:\Program Files (x86)\K-Lite Codec Pack\unins000.exe"
if (Test-Path $kliteUninstallerPath) {
    Start-Process -FilePath $kliteUninstallerPath -ArgumentList '/VERYSILENT', '/NORESTART' -Wait -Verbose
} else {
    Write-Host "K-Lite Codec Pack uninstaller not found at $kliteUninstallerPath"
}

# Other codecs uninstallation depending on system architecture
if ([Environment]::Is64BitOperatingSystem) {
    $otherCodecUninstallerPath = "$env:WINDIR\SysWOW64\Codecs\Uninst.exe"
} else {
    $otherCodecUninstallerPath = "$env:WINDIR\System32\Codecs\Uninst.exe"
}
if (Test-Path $otherCodecUninstallerPath) {
    Start-Process -FilePath $otherCodecUninstallerPath -ArgumentList '/S' -Wait -Verbose
} else {
    Write-Host "Other codec uninstaller not found at $otherCodecUninstallerPath"
}

# Function to set file association
function Set-FileAssociation {
    param (
        [string]$extension,
        [string]$progID
    )

    $keyPath = "HKLM:\SOFTWARE\Classes\$extension"
    
    if (Test-Path $keyPath) {
        Set-ItemProperty -Path $keyPath -Name "(Default)" -Value $progID
        Write-Host "Association set for $extension to $progID"
    } else {
        Write-Host "Registry key for $extension not found."
    }
}

# Associate .avi and .mp4 files with Windows Media Player
Set-FileAssociation -extension ".avi" -progID "WMP11.AssocFile.AVI"
Set-FileAssociation -extension ".mp4" -progID "WMP11.AssocFile.MP4"

try {
    $service = Get-Service -Name "WMPNetworkSvc"
    if ($service.Status -eq 'Running') {
        Stop-Service -Name "WMPNetworkSvc" -Force -Verbose
    }
    Set-Service -Name "WMPNetworkSvc" -StartupType Disabled -Verbose
}
catch {
    Write-Error "Error: $_"
}

# Remove all .swf files from the videos folder
$videoFolderPath = "C:\Program Files (x86)\Retalix\SCO.NET\App\Shufersal\PPL\IMAGES\VIDEOS"
Get-ChildItem $videoFolderPath -Include *.swf -Recurse -Verbose -Force | Remove-Item -Force -Verbose

# Function to revert file extensions for .avi and .mp4 files
function Revert-FileExtensions {
    param (
        [string]$folderPath,
        [string[]]$extensions
    )
    foreach ($extension in $extensions) {
        Get-ChildItem -Path $folderPath -Recurse | Where-Object { $_.Name -match "\.$extension\.[^.]+$" } | ForEach-Object {
            $newName = $_.FullName -replace "\.$extension\.[^.]+$", ".$extension"
            Rename-Item -Path $_.FullName -NewName $newName -Verbose
        }
    }
}

# Revert file extensions for .avi and .mp4 in the specified folder
Revert-FileExtensions -folderPath $videoFolderPath -extensions @("avi", "mp4")

# Register the required DLLs in silent mode
regsvr32 /s jscript.dll
regsvr32 /s vbscript.dll

# Restart the computer
shutdown.exe /r /t 15 /f

exit 0
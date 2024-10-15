# PowerShell script to manage certificates and CRLs

# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
    Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
    Exit
}

# Function to write output to both console and file
function Write-OutputAndLog {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value $Message
}

# Determine if running on Server OS and set log file name
$isServerOS = ($env:OS -eq 'Windows_NT' -and (Get-WmiObject -Class Win32_OperatingSystem).Caption -match 'Server')
if ($isServerOS) {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $logFile = Join-Path $scriptPath "Server OS output.txt"
} else {
    # For client OS, use C:\Temp
    $logPath = "C:\Temp"
    if (-not (Test-Path -Path $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    }
    $logFile = Join-Path $logPath "Client OS output.txt"
}

# Recreate the log file
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}
New-Item $logFile -ItemType File -Force | Out-Null

Clear-Host

Write-OutputAndLog "Starting certificate and CRL management script..." "Cyan"
Write-OutputAndLog "------------------------------------------------------------------------" "Cyan"

$osCaption = (Get-WmiObject -Class Win32_OperatingSystem).Caption
Write-OutputAndLog "The script is running on: $osCaption" "Green"
Write-OutputAndLog ""

# Function to import certificate and verify its location using certutil
function Import-VerifyCertificate {
    param (
        [string]$CertPath,
        [string]$StoreName,
        [string]$CertName
    )
    try {
        Write-OutputAndLog "Processing certificate: $CertName" "Cyan"
        # Import certificate using certutil
        $output = certutil -addstore -f $StoreName $CertPath
        if ($output -match "CertUtil: -addstore command completed successfully.") {
            Write-OutputAndLog "Successfully imported $CertName to $StoreName store." "Green"
            
            # Get the thumbprint of the imported certificate
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
            $thumbprint = $cert.Thumbprint

            # Verify the certificate's presence using Get-ChildItem
            $verifiedCert = Get-ChildItem -Path "Cert:\LocalMachine\$StoreName" | Where-Object { $_.Thumbprint -eq $thumbprint }
            if ($verifiedCert) {
                Write-OutputAndLog "Verified $CertName in $StoreName store." "Green"
            } else {
                Write-OutputAndLog "Failed to verify $CertName in $StoreName store." "Red"
            }
        } else {
            Write-OutputAndLog "Failed to import $CertName to $StoreName store." "Red"
        }
    } catch {
        Write-OutputAndLog ("Error occurred while processing {0}: {1}" -f $CertName, $_.Exception.Message) "Red"
    }
    Write-OutputAndLog ""
}

# Function to import CRL
function Import-CRL {
    param (
        [string]$CRLPath,
        [string]$CRLName
    )
    try {
        Write-OutputAndLog "Processing CRL: $CRLName" "Cyan"
        # Import CRL using certutil
        $output = certutil -addstore -f Root $CRLPath
        if ($output -match "CertUtil: -addstore command completed successfully.") {
            Write-OutputAndLog "Successfully imported CRL: $CRLName" "Green"
        } else {
            Write-OutputAndLog "Failed to import CRL: $CRLName" "Red"
        }
    } catch {
        Write-OutputAndLog ("Error occurred while processing CRL {0}: {1}" -f $CRLName, $_.Exception.Message) "Red"
    }
    Write-OutputAndLog ""
}

# Function to delete LANDesk invdelta files
function Remove-LANDeskInvDeltaFiles {
    $lanDeskPath = "C:\ProgramData\LANDesk\ManagementSuite\DATA"

    if (Test-Path $lanDeskPath) {
        Write-OutputAndLog "Scanning for invdelta files in $lanDeskPath" "Cyan"

        # Get all files including hidden and system files that contain 'invdelta'
        $filesToRemove = Get-ChildItem -Path $lanDeskPath -Force -File | 
                         Where-Object { $_.Name -match 'invdelta' }

        if ($filesToRemove.Count -eq 0) {
            Write-OutputAndLog "No invdelta files found in the directory." "Yellow"
        }

        foreach ($file in $filesToRemove) {
            try {
                # Remove hidden and read-only attributes
                Write-OutputAndLog "Removing attributes from: $($file.Name)" "Yellow"
                Set-ItemProperty -Path $file.FullName -Name Attributes -Value 'Normal'

                # Attempt to delete each file
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                Write-OutputAndLog "Deleted file: $($file.Name)" "Green"
            } catch {
                Write-OutputAndLog ("Failed to delete file {0}: {1}" -f $file.Name, $_.Exception.Message) "Red"
            }
        }

        Write-OutputAndLog "LANDesk file cleanup completed." "Cyan"
    } else {
        Write-OutputAndLog "LANDesk data directory not found at $lanDeskPath" "Yellow"
    }

    Write-OutputAndLog ""  # Print a blank line for spacing
}

if ($isServerOS) {
    # Server OS operations
    Write-OutputAndLog "Performing operations for Server OS..." "Cyan"
    Write-OutputAndLog "--------------------------------------" "Cyan"
    
    # Sources for Digicert CRL and certificate Downloads
    $urls = @(
        'http://crl3.digicert.com/DigiCertAssuredIDRootCA.crl',
        'http://crl3.digicert.com/sha2-assured-cs-g1.crl',
        'http://crl3.digicert.com/DigiCertSHA2AssuredIDCodeSigning.crl',
        'https://cacerts.digicert.com/DigiCertTrustedRootG4.crt',
        'https://cacerts.digicert.com/DigiCertAssuredIDRootCA.crt',
        'https://cacerts.digicert.com/DigiCertSHA2AssuredIDCodeSigningCA.crt'
    )

    # Destination Paths
    $destinationPaths = @(
        'E:\IvantiShare\Packages\RootCerts\DigiCertAssuredIDRootCA.crl',
        'E:\IvantiShare\Packages\RootCerts\sha2-assured-cs-g1.crl',
        'E:\IvantiShare\Packages\RootCerts\DigiCertSHA2AssuredIDCodeSigning.crl',
        'E:\IvantiShare\Packages\RootCerts\DigiCertTrustedRootG4.crt',
        'E:\IvantiShare\Packages\RootCerts\DigiCertAssuredIDRootCA.crt',
        'E:\IvantiShare\Packages\RootCerts\DigiCertSHA2AssuredIDCodeSigningCA.crt'
    )

    # Create destination folder if it does not exist
    $destinationFolder = 'E:\IvantiShare\Packages\RootCerts'
    if (-not (Test-Path -Path $destinationFolder)) {
        New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
        Write-OutputAndLog "Created destination folder: $destinationFolder" "Green"
    }

    # Download the certificates and CRL files
    for ($i = 0; $i -lt $urls.Count; $i++) {
        Write-OutputAndLog "Downloading file from $($urls[$i]) to $($destinationPaths[$i])" "Cyan"
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($urls[$i], $destinationPaths[$i])
        Write-OutputAndLog "Successfully downloaded: $($destinationPaths[$i])" "Green"
        Write-OutputAndLog ""
    }

    # Import certificates and CRLs
    Write-OutputAndLog "Importing certificates and CRLs..." "Cyan"
    foreach ($path in $destinationPaths) {
        if ($path -match '\.crt$') {
            $storeName = if ($path -match 'Root') { "Root" } else { "CA" }
            Import-VerifyCertificate -CertPath $path -StoreName $storeName -CertName (Split-Path $path -Leaf)
        } elseif ($path -match '\.crl$') {
            Import-CRL -CRLPath $path -CRLName (Split-Path $path -Leaf)
        }
    }
} else {
    # Non-Server OS operations
    Write-OutputAndLog "Performing operations for non-Server OS..." "Cyan"
    Write-OutputAndLog "-------------------------------------------" "Cyan"

    # Update the registry to set the redirect registry key
    $registryPath = 'HKLM:\Software\Microsoft\SystemCertificates\AuthRoot\AutoUpdate'
    $registryName = 'RootDirURL'
    $registryValue = 'http://10.250.236.25/ivantishare/Packages/RootCerts/'

    Write-OutputAndLog "Checking registry key..." "Cyan"
    if (Test-Path $registryPath) {
        $currentValue = (Get-ItemProperty -Path $registryPath -Name $registryName -ErrorAction SilentlyContinue).$registryName
        if ($currentValue -eq $registryValue) {
            Write-OutputAndLog "Registry key already exists with correct value." "Green"
        } else {
            Write-OutputAndLog "Updating existing registry key with new value..." "Yellow"
            Set-ItemProperty -Path $registryPath -Name $registryName -Value $registryValue
            Write-OutputAndLog "Registry key updated: $registryPath\$registryName = $registryValue" "Green"
        }
    } else {
        Write-OutputAndLog "Registry key does not exist. Creating new key..." "Yellow"
        New-Item -Path $registryPath -Force | Out-Null
        New-ItemProperty -Path $registryPath -Name $registryName -Value $registryValue -PropertyType String -Force | Out-Null
        Write-OutputAndLog "Registry key created: $registryPath\$registryName = $registryValue" "Green"
    }
    Write-OutputAndLog ""

    # Import certificates and CRLs from remote path
    $remotePath = "\\10.250.236.25\IvantiShare\Packages\RootCerts"
    Write-OutputAndLog "Importing certificates and CRLs from remote path: $remotePath" "Cyan"
    if (Test-Path $remotePath) {
        $files = Get-ChildItem -Path $remotePath -File
        foreach ($file in $files) {
            if ($file.Extension -eq '.crt') {
                $storeName = if ($file.Name -match 'Root') { "Root" } else { "CA" }
                Import-VerifyCertificate -CertPath $file.FullName -StoreName $storeName -CertName $file.Name
            } elseif ($file.Extension -eq '.crl') {
                Import-CRL -CRLPath $file.FullName -CRLName $file.Name
            }
        }
    } else {
        Write-OutputAndLog "Failed to access remote path. Please check network connectivity and permissions." "Red"
    }

    # Clean up LANDesk invdelta files before syncing
    Remove-LANDeskInvDeltaFiles

    # Check and sync with LANDesk client
    $osArchitecture = (Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture
    $ldClientPath = if ($osArchitecture -eq '64-bit') {
        'C:\Program Files (x86)\LANDesk\LDCLIENT\ldiscn32.exe'
    } else {
        'C:\Program Files\LANDesk\LDCLIENT\ldiscn32.exe'
    }

    if (Test-Path -Path $ldClientPath) {
        $ldiscnProcess = Get-Process -Name "ldiscn32" -ErrorAction SilentlyContinue
        if ($ldiscnProcess) {
            Write-OutputAndLog "LANDesk client (ldiscn32.exe) is already running. Skipping sync..." "Yellow"
        } else {
            Write-OutputAndLog "Syncing with LANDesk client ($osArchitecture)..." "Cyan"
            & "$ldClientPath" /F /SYNC
            Write-OutputAndLog "LANDesk client sync completed ($osArchitecture)" "Green"
        }
    } else {
        Write-OutputAndLog "LANDesk client executable not found" "Yellow"
    }
}

Write-OutputAndLog "------------------------------------------------------------------------" "Cyan"
Write-OutputAndLog "Script execution completed." "Cyan"
Write-OutputAndLog "Log file saved to: $logFile" "Cyan"

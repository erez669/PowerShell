If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

Add-Type -AssemblyName System.Windows.Forms

# Set the destination directory
$destinationDir = "C:\install\CoretxCleaner"

# Create the directory if it does not exist
if (!(Test-Path -Path $destinationDir)) {
    New-Item -Path $destinationDir -ItemType Directory
}

# Copy files from the network share to the local directory
$sourceDir = "\\10.250.236.25\IvantiShare\Packages\SHARED\PaloAlto\XdrAgentCleaner"
robocopy $sourceDir $destinationDir /E

function Check-ProgramInstalled($programName) {
    $keyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $keyPathWow = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    $allKeys = Get-ChildItem $keyPath, $keyPathWow -ErrorAction SilentlyContinue
    foreach ($key in $allKeys) {
        $currentKey = Get-ItemProperty $key.PSPath
        if ($currentKey.DisplayName -eq $programName) {
            return $true
        }
    }
    return $false
}

function Prompt-ForPassword {
    $maxRetries = 3
    $retryCount = 0

    while ($retryCount -lt $maxRetries) {
        Write-Host "Attempt number: $($retryCount + 1)"

        $password = Read-Host -Prompt "Enter Password for XDR Cleanup Tool" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        # Run the cleaner tool
        Write-Host "Running XDR agent cleaner..."
        & "$destinationDir\XdrAgentCleaner.exe" --password $plainPassword 2>&1

        # Wait for a brief moment to allow the cleaner to operate
        Start-Sleep -Seconds 5

        # Check for the presence of the XDR agent
        Write-Host "Checking for the presence of the XDR agent..."
        $cyserverRunning = Get-Process cyserver -ErrorAction SilentlyContinue
        $programInstalled = Check-ProgramInstalled "Cortex XDR"

        if (-Not $cyserverRunning -and -Not $programInstalled) {
            Write-Host "XDR agent removal successful."
            return $true
        }

        Write-Host "XDR agent still present or unable to verify its removal."
        $retryCount++
    }

    Write-Host "Maximum retries reached. Please check the tool or password."
    return $false
}

# Main script execution
$removalSuccessful = Prompt-ForPassword

if ($removalSuccessful) {
    # Stop explorer.exe
    Stop-Process -Name explorer -Force

    # Start explorer.exe without opening a folder
    [void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    [System.Windows.Forms.SendKeys]::SendWait("{ESC}")

    # Sleep briefly to allow explorer.exe to start
    Start-Sleep -Seconds 2

    # Remove Palo Alto Networks directories
    $pathsToRemove = @("C:\Program Files\Palo Alto Networks", "C:\Program Files (x86)\Palo Alto Networks")

    foreach ($path in $pathsToRemove) {
        if (Test-Path -Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue -Verbose
            Write-Host "Attempted to remove directory: $path"
        } else {
            Write-Host "Directory not found, skipping: $path"
        }
    }

    # Pause 5 seconds
    Start-Sleep -Seconds 5

    # Display message box (not minimized)
    $result = [System.Windows.Forms.MessageBox]::Show("Process completed successfully, please reboot your machine to complete the removal process", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

    # Check the result (if needed)
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        # User clicked OK
        Write-Host "User clicked OK."
    } else {
        Write-Host "User did not click OK."
    }

    # Remove the C:\install\CoretxCleaner folder and its contents
    Write-Host "Removing the folder C:\install\CoretxCleaner and its contents..."
    Remove-Item -Path "C:\install\CoretxCleaner" -Recurse -Force -Verbose
    Write-Host "Folder removed."
} else {
    Write-Host "Exiting script due to unsuccessful XDR agent removal."
}
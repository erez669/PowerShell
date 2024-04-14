Clear-Host

do {
    Write-Host "`n"  # For creating space
    $serverName = Read-Host "Enter hostname for start or stop DHCPServer or write 'q' letter and press enter to exit this script"

    if ($serverName -eq 'q') {
        Write-Host "Exiting."
        break
    }

    Write-Host "Press 0 to stop DHCPServer, press 1 to enable it, press q to exit this script"

    $keyPress = [System.Console]::ReadKey($true)  # Suppress the "Enter" key after pressing the command
    $key = $keyPress.KeyChar

    if ($key -eq '0') {
        $action = "stop"
    } elseif ($key -eq '1') {
        $action = "start"
    } elseif ($key -eq 'q') {
        Write-Host "Exiting."
        break
    } else {
        Write-Host "Invalid key pressed. Try again."
        continue
    }

    # Define the script block to execute remotely
    $scriptBlock = {
    param ($serverName, $action)
    try {
        # This will set the service to manual start whether starting or stopping
        Write-Host "Setting DHCPServer to manual start."
        Set-Service -Name DHCPServer -StartupType Manual -Verbose

        if ($action -eq "start") {
            Write-Host "Starting DHCPServer."
            Start-Service -Name DHCPServer -Verbose
        } elseif ($action -eq "stop") {
            Write-Host "Stopping DHCPServer."
            Stop-Service -Name DHCPServer -Verbose
        } else {
            Write-Host "Invalid action specified."
        }
    } catch {
        Write-Host "Error: $($_.Exception.Message)"
        exit 1
    }
}

    try {
        # Execute the script block remotely
        Invoke-Command -ComputerName $serverName -ScriptBlock $scriptBlock -ArgumentList $serverName, $action -ErrorAction Stop
    }
    catch {
        Write-Host "An error occurred: $($_.Exception.Message)"
    }

} while ($true)

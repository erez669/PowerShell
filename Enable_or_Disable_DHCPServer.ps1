Clear-Host

do {
    write-host "`n" # for creating space
    $serverName = Read-Host "Enter hostname for start or stop DHCPServer or write 'q' letter and press enter to exit this script"

    if ($serverName -eq 'q') {
    Write-Host "Exiting."
    break
    }

    Write-Host "Press 0 to stop DHCPServer, press 1 to enable it, press q to exit this script"

    $keyPress = [System.Console]::ReadKey($true) # for suppress the "Enter" key after pressing the command
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
        if ($action -eq "start") {
            Write-Host "Starting DHCPServer"
            Start-Service -Name DHCPServer -Verbose
        }
        if ($action -eq "stop") {
            Write-Host "Stopping DHCPServer"
            Stop-Service -Name DHCPServer -Verbose
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
Clear-Host

# Get local hostname
$localHostname = $env:COMPUTERNAME
Write-Host "`nLocal workstation hostname is: $localHostname" -ForegroundColor Yellow

# Extract the three digits - v2 compatible method
$pattern = "POS-(\d{3})"
$match = [regex]::Match($localHostname, $pattern)
$serverNum = $match.Groups[1].Value

Write-Host "Extracted number from hostname: $serverNum" -ForegroundColor Cyan

# Get IP addresses in the 10.18.88.x or 10.118.88.x range - PowerShell v2 compatible
$ipAddresses = $null
$networkAdapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
foreach ($adapter in $networkAdapters) {
    if ($adapter.IPAddress) {
        foreach ($ip in $adapter.IPAddress) {
            if ($ip -match "^10\.18\.88\." -or $ip -match "^10\.118\.88\.") {
                $ipAddresses = $true
                break
            }
        }
    }
    if ($ipAddresses) { break }
}

# Check for 888 in hostname or IP in the specific ranges
if ($serverNum -eq "888" -or $ipAddresses) {
    if ($serverNum -eq "888") {
        Write-Host "Server number is 888. Skipping script execution." -ForegroundColor Yellow
    }
    if ($ipAddresses) {
        Write-Host "IP address in 10.18.88.x or 10.118.88.x range detected. Skipping script execution." -ForegroundColor Yellow
        $foundIPs = @()
        foreach ($adapter in $networkAdapters) {
            if ($adapter.IPAddress) {
                foreach ($ip in $adapter.IPAddress) {
                    if ($ip -match "^10\.18\.88\." -or $ip -match "^10\.118\.88\.") {
                        $foundIPs += $ip
                    }
                }
            }
        }
        foreach ($ip in $foundIPs) {
            Write-Host "Detected IP: $ip" -ForegroundColor Cyan
        }
    }
    exit 0
}

# Initialize server connection success flag
$serverConnected = $false

# Try primary server first (WLPOSSRV)
$primaryServerName = "WLPOSSRV$serverNum"
$failbackServerName = "PLPOSSRV$serverNum"
Write-Host "Primary server name: $primaryServerName" -ForegroundColor Green
Write-Host "Failback server name: $failbackServerName" -ForegroundColor Green

$serviceName = "DHCPServer"
Write-Host "Target service name: $serviceName" -ForegroundColor Green

Write-Host "`nAttempting to connect to servers..." -ForegroundColor Yellow

# Function to manage DHCP service on a server
function Manage-DHCPService {
    param (
        [string]$serverName,
        [string]$serviceName
    )
    
    try {
        # Test if server is reachable - PowerShell v2 compatible method
        $pingResult = $false
        try {
            $ping = New-Object System.Net.NetworkInformation.Ping
            $reply = $ping.Send($serverName)
            $pingResult = ($reply.Status -eq 'Success')
        } catch {
            $pingResult = $false
        }
        
        if (-not $pingResult) {
            Write-Host "Cannot reach $serverName (ping failed)" -ForegroundColor Red
            return $false
        }
        
        # Query service status and configuration
        $scCmd = "sc.exe \\$serverName query $serviceName"
        $scConfigCmd = "sc.exe \\$serverName qc $serviceName"
        $serviceStatus = Invoke-Expression $scCmd
        $serviceConfig = Invoke-Expression $scConfigCmd
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully connected to $serverName" -ForegroundColor Green
            
            # Check current startup type
            $startupType = ($serviceConfig | Select-String "START_TYPE" | Out-String)
            if ($startupType -match "AUTO") {
                Write-Host "`nChanging startup type from Automatic to Manual..." -ForegroundColor Yellow
                $scConfigCmd = "sc.exe \\$serverName config $serviceName start= demand"
                Invoke-Expression $scConfigCmd | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Startup type changed to Manual successfully" -ForegroundColor Green
                } else {
                    Write-Host "Failed to change startup type" -ForegroundColor Red
                }
            } else {
                Write-Host "`nStartup type is already set to Manual" -ForegroundColor Yellow
            }
            
            # Check if service is running before attempting to stop
            $currentState = ($serviceStatus | Select-String "STATE" | Out-String)
            if ($currentState -match "RUNNING") {
                Write-Host "`nAttempting to stop DHCP Server service..." -ForegroundColor Yellow
                $scStopCmd = "sc.exe \\$serverName stop $serviceName"
                Invoke-Expression $scStopCmd | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Service stopped successfully" -ForegroundColor Green
                } else {
                    Write-Host "Failed to stop service" -ForegroundColor Red
                }
            } else {
                Write-Host "`nService is already stopped" -ForegroundColor Yellow
            }
            
            # Get final status
            $finalStatus = Invoke-Expression $scCmd
            $finalConfig = Invoke-Expression $scConfigCmd
            Write-Host "`nFinal service status:" -ForegroundColor Cyan
            $finalStatus | ForEach-Object {
                if ($_ -match "STATE") {
                    Write-Host $_ -ForegroundColor Green
                }
            }
            Write-Host "Final startup type:" -ForegroundColor Cyan
            $finalConfig | ForEach-Object {
                if ($_ -match "START_TYPE") {
                    $startType = $_ -replace ".*:\s*\d+\s*", ""  # Remove everything before the type
                    if ($startType -match "DEMAND") {
                        Write-Host "        START_TYPE    : Manual" -ForegroundColor Green
                    } else {
                        Write-Host "        $_" -ForegroundColor Green
                    }
                }
            }
            return $true
        } else {
            Write-Host "Failed to connect to service on $serverName" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "`nError occurred when connecting to $($serverName):" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

# Try to connect to primary server first
$serverConnected = Manage-DHCPService -serverName $primaryServerName -serviceName $serviceName

# If primary server fails, try the failback server
if (-not $serverConnected) {
    Write-Host "`n### Primary server unavailable. Trying failback server: $failbackServerName ###" -ForegroundColor Yellow
    
    $serverConnected = Manage-DHCPService -serverName $failbackServerName -serviceName $serviceName
    
    if (-not $serverConnected) {
        Write-Host "`n!!! Both primary and fallback servers are unavailable !!!" -ForegroundColor Red
    }
}

Write-Host "`nScript execution completed" -ForegroundColor Yellow
exit 0
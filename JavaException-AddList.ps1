If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}

# List of IP addresses
$ipAddresses = @(
    "010.010.001.001",
    "010.010.001.002",
    "010.010.017.001",
    "010.010.017.002",
    "010.010.019.001",
    "010.010.019.002",
    "010.010.033.001",
    "010.010.033.002",
    "010.010.062.001",
    "010.010.062.002",
    "010.010.065.001",
    "010.010.065.002",
    "010.010.069.001",
    "010.010.069.002",
    "010.010.071.001",
    "010.010.071.002",
    "010.010.072.001",
    "010.010.073.001",
    "010.010.073.002",
    "010.010.077.001",
    "010.010.077.002",
    "010.010.083.001",
    "010.010.083.002",
    "010.010.091.001",
    "010.010.091.002",
    "010.010.095.001",
    "010.010.095.002",
    "010.010.097.001",
    "010.010.097.002",
    "010.010.098.001",
    "010.010.098.002",
    "010.011.014.001",
    "010.011.014.002",
    "010.011.016.001",
    "010.011.016.002",
    "010.011.017.001",
    "010.011.017.002",
    "010.011.019.001",
    "010.011.019.002",
    "010.011.022.001",
    "010.011.022.002",
    "010.011.023.001",
    "010.011.023.002",
    "010.011.028.001",
    "010.011.028.002",
    "010.011.029.001",
    "010.011.030.001",
    "010.011.030.002",
    "010.011.032.001",
    "010.011.032.002",
    "010.011.038.001",
    "010.011.038.002",
    "010.011.039.001",
    "010.011.039.002",
    "010.011.041.001",
    "010.011.041.002",
    "010.011.056.001",
    "010.011.056.002",
    "010.011.057.001",
    "010.011.057.002",
    "010.011.066.001",
    "010.011.066.002",
    "010.011.068.001",
    "010.011.068.002",
    "010.011.074.001",
    "010.011.074.002",
    "010.011.076.001",
    "010.011.076.002",
    "010.011.081.001",
    "010.011.081.002",
    "010.011.082.001",
    "010.011.082.002",
    "010.011.087.001",
    "010.011.087.002",
    "010.011.093.001",
    "010.011.093.002",
    "010.012.003.001",
    "010.012.003.002",
    "010.012.009.001",
    "010.012.009.002",
    "010.012.018.001",
    "010.012.018.002",
    "010.012.032.001",
    "010.012.032.002",
    "010.012.034.001",
    "010.012.034.002",
    "010.012.066.001",
    "010.012.066.002",
    "010.012.069.001",
    "010.012.069.002",
    "010.012.071.001",
    "010.012.071.002",
    "010.012.072.001",
    "010.012.072.002",
    "010.012.082.001",
    "010.012.082.002",
    "010.012.095.001",
    "010.012.095.002",
    "010.012.097.001",
    "010.012.097.002",
    "010.013.012.001",
    "010.013.012.002",
    "010.013.042.001",
    "010.013.042.002",
    "010.013.044.001",
    "010.013.044.002",
    "010.013.050.001",
    "010.013.050.002",
    "010.013.059.001",
    "010.013.059.002",
    "010.013.089.001",
    "010.013.089.002",
    "010.014.096.001",
    "010.014.096.002",
    "010.016.008.001",
    "010.016.008.002"
)

# Path to the exception.sites file
$exceptionFilePath = "$env:APPDATA\..\LocalLow\Sun\Java\Deployment\security\exception.sites"

# Ensure the file exists
if (-not (Test-Path -Path $exceptionFilePath)) {
    New-Item -Path $exceptionFilePath -ItemType File
}

function Remove-LeadingZerosAndAdjustLastOctet {
    param (
        [String]$ip
    )

    # Split the IP into octets, cast each to an integer to remove leading zeros
    $octets = $ip -split '\.' | ForEach-Object { [int]$_ }

    # Correct the last octet if it ends with 1, change to 5; if it ends with 2, change to 6
    $lastOctet = $octets[3]
    if ($lastOctet -eq 1) {
        $octets[3] = 5
    } elseif ($lastOctet -eq 2) {
        $octets[3] = 6
    }

    # Reassemble the IP address
    return ($octets -join '.')
}

# Use the updated function in the script
foreach ($ip in $ipAddresses) {
    if (-not [string]::IsNullOrWhiteSpace($ip)) {
        $formattedIP = Remove-LeadingZerosAndAdjustLastOctet $ip
        $entry = "https://$formattedIP"
        Add-Content -Path $exceptionFilePath -Value $entry
    }
}

Write-Host "IP addresses have been adjusted and added to the Java exception list."
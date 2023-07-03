# Define the config file paths
$configFilePaths = @(
    'C:\retalix\wingpos\MxParams.Config',
    'C:\Program Files\Retalix\SCO.NET\App\MxParams.Config',
    'C:\Program Files (x86)\Retalix\SCO.NET\App\MxParams.Config'
)

# Define the output CSV file path
$outputCsvFilePath = '\\ivantiappsrv\IvantiShare\Packages\POS\TerminalType\TerminalTypes.csv'

# Get device hostname
$deviceHostname = [System.Net.Dns]::GetHostName()

# Check if the output CSV file exists. If not, create it and add the header row
if (!(Test-Path -Path $outputCsvFilePath)) {
    $headerRow = "HostName,TerminalModel,ConfigFilePath"
    Add-Content -Path $outputCsvFilePath -Value $headerRow
}

# Iterate over each config file path
foreach ($configFilePath in $configFilePaths) {
    # Skip this iteration if the file does not exist
    if (!(Test-Path -Path $configFilePath)) {
        Write-Host "File does not exist: $configFilePath"
        continue
    }

    # Load XML content from the .config file
    [xml]$configData = Get-Content -Path $configFilePath

    # Extract TerminalModel key value pair
    $terminalModelValue = $configData.configuration.appSettings.add | Where-Object { $_.key -eq 'TerminalModel' } | Select-Object -ExpandProperty value

    # Create a new line for the CSV file
    $csvLine = "$deviceHostname,$terminalModelValue,$configFilePath"

    # Append the new line to the CSV file
    Add-Content -Path $outputCsvFilePath -Value $csvLine -Verbose
}
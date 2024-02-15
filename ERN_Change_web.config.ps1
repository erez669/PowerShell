$VerbosePreference = 'Continue'

$Snif = $env:computername.Substring(8,3)
$csvFile = "\\reportsrv01\pub\ERN.csv"
$webConfigFile = "D:\retalix\fpstore\WSGpos\web.config"

# Determine the encoding of the web.config file
$reader = [System.IO.StreamReader]::new($webConfigFile, [System.Text.Encoding]::Default, $true)
$encoding = $reader.CurrentEncoding
$reader.Close()

$Csv = Import-Csv $csvFile
$filteredRows = $Csv | Where-Object { $_.SNIF.PadLeft(3,'0') -eq $Snif }
$filteredRows | ForEach-Object {
    $ern = $_.ERN
    Write-Verbose "ERN value from ERN.csv file is: $ern"

    # Read current content of web.config
    $content = Get-Content $webConfigFile -Raw
    $pattern = '(?<=<add key="ErnMId" value=")[^"]*(?=" />)'
    
    # Check if the current ERN value in web.config matches the ERN value in CSV
    if ($content -match $pattern -and $matches[0] -eq $ern) {
        Write-Host "ERN Value $ern already exists in your web.config file"
    } else {
        $updatedContent = $content -replace $pattern, $ern
        [System.IO.File]::WriteAllText($webConfigFile, $updatedContent, $encoding) # Use the determined encoding
        Write-Verbose "Updated web.config file with new ErnMId value: $ern"
    }
    break
}

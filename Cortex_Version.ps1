# Check for admin rights
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

# Output path 
$outputPath = "\\ivantiappsrv.corp.supersol.co.il\IvantiShare\Packages\SHARED\PaloAlto\VersionCheck\Cortex_Version.csv"

# Get installed products
$regPath = "HKLM:\SOFTWARE\Classes\Installer\Products\*"

Write-Host "Searching registry for installed products..."
$productKeys = Get-ChildItem $regPath

Write-Host "Found $($productKeys.Count) products. Checking for Cortex XDR..."

# Check for Cortex 
$productNameData = $null
$hostname = [System.Net.Dns]::GetHostName() # Initialize the hostname variable

foreach ($key in $productKeys) {
    $productName = (Get-ItemProperty $key.PSPath).ProductName
    if ($productName -and $productName -match "Cortex XDR") {
        $productNameData = $productName
        Write-Host "Cortex XDR found: $productNameData" 
        break
    }
}

# Output to CSV 
if ($productNameData) {

    $csvLine = "$($hostname),$($productNameData)`n"

    try {
        # Check if the file exists and write the header only if it's new or empty
        if (-Not (Test-Path -Path $outputPath) -Or (Get-Content -Path $outputPath).Length -eq 0) {
            $csvHeader = "ComputerName,ProductData`n"
            $csvLine = $csvHeader + $csvLine
        }

        # Open file for append
        $file = [System.IO.File]::Open($outputPath, [System.IO.FileMode]::Append)

        # Create StreamWriter from FileStream
        $writer = New-Object System.IO.StreamWriter($file)  

        # Write line
        $writer.WriteLine($csvLine)

        # Close StreamWriter and FileStream
        $writer.Close()
        $file.Close()

    } catch {
        Write-Error "Error appending to file: $_"
    }

    Write-Host "Details added to $outputPath"

}
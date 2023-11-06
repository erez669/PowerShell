# Check for admin rights
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

# Output path 
$outputPath = "\\myserver\VersionCheck\Cortex_Version.csv"

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
    # Line of data to append
    $csvLine = "$($hostname),$($productNameData)`n"
    
    try {
        # Check if the file exists
        $fileExists = Test-Path -Path $outputPath -Verbose

        # Open file for append or create if it doesn't exist
        $file = [System.IO.File]::Open($outputPath, [System.IO.FileMode]::Append)

        # Create StreamWriter from FileStream
        $writer = New-Object System.IO.StreamWriter($file) -Verbose

        # If the file is new or empty, write the header
        if (-Not $fileExists -Or $file.Length -eq 0) {
            $csvHeader = "ComputerName,ProductData`n"
            $writer.WriteLine($csvHeader)
        }

        # Write line of data
        $writer.WriteLine($csvLine)

        # Close StreamWriter and FileStream
        $writer.Close()
        $file.Close()

    } catch {
        Write-Error "Error appending to file: $_"
    }

    Write-Host "Details added to $outputPath"
}

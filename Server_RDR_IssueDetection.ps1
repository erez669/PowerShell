Clear-Host

# Search patterns
$errorLines = @(
  'Error !!! RDRConfigurationUploadModule: server name - RSOCTLGSQL. Error There is no row at position 0.',
  'Error: Error in update process !!!!!!!',
  'There is no row at position 0.'
)

# Search folder
$folderPath = 'C:\installLogs'

Write-Host "Searching files in $folderPath..."

# Get newest file
$txtFiles = Get-ChildItem $folderPath -Filter *.txt | Sort-Object LastWriteTime -Descending 
$newestFile = $txtFiles | Select-Object -First 1

# Read content
$content = Get-Content $newestFile.FullName

# Check each line
foreach ($line in $content) {

  # Check for matches
  foreach ($err in $errorLines) {

    if ($line -match $err) {
    
      # Print match and exit
      Write-Host "Found error:"
      Write-Host $line
      Write-Host "Match found! Exiting with code 8"  
      exit 8
    
    }

  }

}

# No matches
Write-Host "No errors in $($newestFile.Name)" 
exit 0